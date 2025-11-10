import Vision
import AVFoundation
import CoreGraphics
import AppKit

class FaceLandmarkService {
    
    private let request = VNDetectFaceLandmarksRequest()
    
    struct EyeCropResult {
        let leftEye: NSImage
        let rightEye: NSImage
        let leftROI: CGRect
        let rightROI: CGRect
        let poseFeatures: [CGFloat]
        let distanceProxy: CGFloat
        let lidGap: CGFloat
        let interPupilDistance: CGFloat
        let usable: Bool
    }
    
    func processFrame(_ sampleBuffer: CMSampleBuffer) throws -> EyeCropResult {
        let handler = VNImageRequestHandler(cmSampleBuffer: sampleBuffer, orientation: .up, options: [:])
        try handler.perform([request])
        
        guard let observation = request.results?.first,
              observation.confidence > 0.7,
              let landmarks = observation.landmarks else {
            throw CalibrationError.faceLandmarksNotFound
        }
        
        // Get pixel buffer
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            throw CalibrationError.invalidFrameData
        }
        
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        
        // Calculate features
        let interPupil = calculateInterPupilDistance(landmarks: landmarks, imageSize: ciImage.extent.size)
        let distProxy = interPupil / ciImage.extent.size.height
        let lidGap = calculateLidGap(landmarks: landmarks)
        let pose = calculatePoseFeatures(landmarks: landmarks, interPupil: interPupil)
        
        // Crop eyes
        let leftROI = getEyeROI(landmarks: landmarks, isLeft: true, imageSize: ciImage.extent.size, observation: observation)
        let rightROI = getEyeROI(landmarks: landmarks, isLeft: false, imageSize: ciImage.extent.size, observation: observation)
        
        // Validate ROIs
        guard leftROI.width > 0 && leftROI.height > 0 &&
              rightROI.width > 0 && rightROI.height > 0 &&
              ciImage.extent.contains(leftROI) &&
              ciImage.extent.contains(rightROI) else {
            print("⚠️ Invalid ROI - Left: \(leftROI), Right: \(rightROI), Image: \(ciImage.extent)")
            throw CalibrationError.eyeCropFailed
        }
        
        guard let leftEyeImage = cropAndResize(ciImage, roi: leftROI, context: context),
              let rightEyeImage = cropAndResize(ciImage, roi: rightROI, context: context) else {
            throw CalibrationError.eyeCropFailed
        }
        
        // Quality checks - more lenient thresholds
        let usable = lidGap > 0.15 && observation.confidence > 0.5
        
        if !usable {
            print("⚠️ Frame marked unusable - lidGap: \(lidGap), confidence: \(observation.confidence)")
        }
        
        return EyeCropResult(
            leftEye: leftEyeImage,
            rightEye: rightEyeImage,
            leftROI: leftROI,
            rightROI: rightROI,
            poseFeatures: pose,
            distanceProxy: distProxy,
            lidGap: lidGap,
            interPupilDistance: interPupil,
            usable: usable
        )
    }
    
    private func getEyeROI(landmarks: VNFaceLandmarks2D, isLeft: Bool, imageSize: CGSize, observation: VNFaceObservation) -> CGRect {
        let eyeRegion = isLeft ? landmarks.leftEye : landmarks.rightEye
        
        guard let eyeRegion = eyeRegion else {
            return .zero
        }
        
        let points = eyeRegion.normalizedPoints
        guard !points.isEmpty else { return .zero }
        
        var minX = points[0].x
        var maxX = points[0].x
        var minY = points[0].y
        var maxY = points[0].y
        
        for point in points {
            minX = min(minX, point.x)
            maxX = max(maxX, point.x)
            minY = min(minY, point.y)
            maxY = max(maxY, point.y)
        }
        
        // Convert to image coordinates
        let boundingBox = observation.boundingBox
        let faceRect = VNImageRectForNormalizedRect(boundingBox, Int(imageSize.width), Int(imageSize.height))
        
        let eyeWidth = (maxX - minX) * faceRect.width
        let eyeHeight = (maxY - minY) * faceRect.height
        let eyeX = faceRect.origin.x + minX * faceRect.width
        let eyeY = faceRect.origin.y + minY * faceRect.height
        
        // Expand by 20%
        let expansion: CGFloat = 0.20
        let expandedWidth = eyeWidth * (1 + expansion)
        let expandedHeight = eyeHeight * (1 + expansion)
        let expandedX = eyeX - (expandedWidth - eyeWidth) / 2
        let expandedY = eyeY - (expandedHeight - eyeHeight) / 2
        
        return CGRect(x: expandedX, y: expandedY, width: expandedWidth, height: expandedHeight)
    }
    
    private func cropAndResize(_ image: CIImage, roi: CGRect, context: CIContext) -> NSImage? {
        let cropped = image.cropped(to: roi)
        let resized = cropped.transformed(by: CGAffineTransform(scaleX: 60.0 / roi.width, y: 36.0 / roi.height))
        
        guard let cgImage = context.createCGImage(resized, from: resized.extent) else {
            return nil
        }
        
        // Convert to grayscale
        let grayscaleContext = CGContext(
            data: nil,
            width: 60,
            height: 36,
            bitsPerComponent: 8,
            bytesPerRow: 60,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        )
        
        grayscaleContext?.draw(cgImage, in: CGRect(x: 0, y: 0, width: 60, height: 36))
        
        guard let grayscaleCG = grayscaleContext?.makeImage() else {
            return nil
        }
        
        return NSImage(cgImage: grayscaleCG, size: NSSize(width: 60, height: 36))
    }
    
    private func calculateInterPupilDistance(landmarks: VNFaceLandmarks2D, imageSize: CGSize) -> CGFloat {
        guard let leftPupil = landmarks.leftPupil?.normalizedPoints.first,
              let rightPupil = landmarks.rightPupil?.normalizedPoints.first else {
            return 100.0 // Default fallback
        }
        
        let dx = (rightPupil.x - leftPupil.x) * imageSize.width
        let dy = (rightPupil.y - leftPupil.y) * imageSize.height
        return sqrt(dx * dx + dy * dy)
    }
    
    private func calculateLidGap(landmarks: VNFaceLandmarks2D) -> CGFloat {
        let leftGap = normLidGap(leftEye: landmarks)
        let rightGap = normLidGap(rightEye: landmarks)
        return (leftGap + rightGap) / 2.0
    }
    
    private func normLidGap(leftEye landmarks: VNFaceLandmarks2D) -> CGFloat {
        guard let leftEye = landmarks.leftEye else { return 0.25 }
        let points = leftEye.normalizedPoints
        guard points.count >= 6 else { return 0.25 }
        
        // Top and bottom lid midpoints
        let upper = CGPoint(x: (points[1].x + points[2].x) / 2, y: (points[1].y + points[2].y) / 2)
        let lower = CGPoint(x: (points[4].x + points[5].x) / 2, y: (points[4].y + points[5].y) / 2)
        let gap = distance(upper, lower)
        
        // Eye width (inner to outer corner)
        let width = max(distance(points[0], points[3]), 0.001)
        return gap / width
    }
    
    private func normLidGap(rightEye landmarks: VNFaceLandmarks2D) -> CGFloat {
        guard let rightEye = landmarks.rightEye else { return 0.25 }
        let points = rightEye.normalizedPoints
        guard points.count >= 6 else { return 0.25 }
        
        let upper = CGPoint(x: (points[1].x + points[2].x) / 2, y: (points[1].y + points[2].y) / 2)
        let lower = CGPoint(x: (points[4].x + points[5].x) / 2, y: (points[4].y + points[5].y) / 2)
        let gap = distance(upper, lower)
        let width = max(distance(points[0], points[3]), 0.001)
        return gap / width
    }
    
    private func calculatePoseFeatures(landmarks: VNFaceLandmarks2D, interPupil: CGFloat) -> [CGFloat] {
        // Extract 8 landmark deltas normalized by inter-pupil distance
        guard let noseTip = landmarks.noseCrest?.normalizedPoints.first,
              let leftEye = landmarks.leftEye?.normalizedPoints.first,
              let rightEye = landmarks.rightEye?.normalizedPoints.first,
              let leftMouth = landmarks.outerLips?.normalizedPoints.first,
              let rightMouth = landmarks.outerLips?.normalizedPoints.last else {
            return [0, 0, 0, 0, 0, 0, 0, 0]
        }
        
        let normFactor = max(interPupil, 1.0)
        
        return [
            (noseTip.x - leftEye.x) / normFactor,
            (noseTip.y - leftEye.y) / normFactor,
            (rightEye.x - leftEye.x) / normFactor,
            (rightEye.y - leftEye.y) / normFactor,
            (leftMouth.x - leftEye.x) / normFactor,
            (leftMouth.y - leftEye.y) / normFactor,
            (rightMouth.x - rightEye.x) / normFactor,
            (rightMouth.y - rightEye.y) / normFactor
        ]
    }
    
    private func distance(_ p1: CGPoint, _ p2: CGPoint) -> CGFloat {
        let dx = p1.x - p2.x
        let dy = p1.y - p2.y
        return sqrt(dx * dx + dy * dy)
    }
}
