import SwiftUI
import AVFoundation
import Vision // Import Apple's Vision Framework

// This helper view displays the camera feed in a SwiftUI-compatible way.
struct CameraPreviewView: NSViewRepresentable {
    
    let previewLayer: AVCaptureVideoPreviewLayer
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.layer = previewLayer
        view.layer?.cornerRadius = 10
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
}


class CameraService: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    let session = AVCaptureSession()
    @Published var previewLayer: AVCaptureVideoPreviewLayer!
    
    @Published var fps: Double = 0.0
    
    // We now track left and right hands separately
    @Published var leftHandGesture: String = "---"
    @Published var rightHandGesture: String = "---"
    
    private var frameCount: Int = 0
    private var lastTimestamp = Date.timeIntervalSinceReferenceDate
    
    // Vision request for detecting hands
    private var handPoseRequest = VNDetectHumanHandPoseRequest()
    
    override init() {
        super.init()
        
        self.previewLayer = AVCaptureVideoPreviewLayer(session: self.session)
        self.previewLayer.videoGravity = .resizeAspectFill
        
        // We now look for TWO hands
        handPoseRequest.maximumHandCount = 2
        
        checkCameraPermission()
    }
    
    // Check if we have camera permission, or request it
    func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    DispatchQueue.main.async {
                        self?.setupCamera()
                    }
                }
            }
        case .denied, .restricted:
            print("Camera permission denied.")
        @unknown default:
            break
        }
    }
    
    // Set up the AVFoundation camera session
    private func setupCamera() {
        guard let videoDevice = AVCaptureDevice.default(for: .video) else {
            print("Could not find default video device.")
            return
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: videoDevice)
            if session.canAddInput(input) {
                session.addInput(input)
            }
            
            // This is the output that gives us the raw video frames
            let videoOutput = AVCaptureVideoDataOutput()
            videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoDataQueue", qos: .userInitiated))
            
            if session.canAddOutput(videoOutput) {
                session.addOutput(videoOutput)
            }
            
            DispatchQueue.global(qos: .userInitiated).async {
                self.session.startRunning()
            }
        } catch {
            print("Error setting up camera: \(error.localizedDescription)")
        }
    }
    
    // This function is called for every single frame from the camera
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        // 1. Calculate FPS
        let currentTime = Date.timeIntervalSinceReferenceDate
        frameCount += 1
        let elapsedTime = currentTime - lastTimestamp
        
        if elapsedTime >= 1.0 {
            let newFPS = Double(frameCount) / elapsedTime
            DispatchQueue.main.async { self.fps = newFPS } // Update FPS
            frameCount = 0
            lastTimestamp = currentTime
        }
        
        var newLeftGesture = "---"
        var newRightGesture = "---"
        
        do {
            let handler = VNImageRequestHandler(cmSampleBuffer: sampleBuffer, orientation: .up, options: [:])
            
            // Perform the request using the new handler
            try handler.perform([handPoseRequest])
            
            // Check if we found any hands
            if let results = handPoseRequest.results, !results.isEmpty {
                
                // Loop through all detected hands (up to 2)
                for handObservation in results {
                    
                    let handedness = handObservation.chirality
                    
                    // --- SIMPLIFIED ---
                    let gesture = detectFist(from: handObservation)
                    // ----------------
                    
                    // Assign the gesture to the correct property
                    if handedness == .left {
                        newLeftGesture = gesture
                    } else if handedness == .right {
                        newRightGesture = gesture
                    }
                }
            }
        } catch {
            // Don't print an error every frame, just ignore it
        }
        
        // 3. Update UI (Only if Gestures CHANGED)
        if newLeftGesture != self.leftHandGesture {
            DispatchQueue.main.async {
                self.leftHandGesture = newLeftGesture
            }
        }
        if newRightGesture != self.rightHandGesture {
            DispatchQueue.main.async {
                self.rightHandGesture = newRightGesture
            }
        }
    }
    
    // --- UPDATED: Simplified detectGesture ---
    private func detectFist(from handObservation: VNHumanHandPoseObservation) -> String {
        // Get all the joints we need for Fist
        guard
            let wristPoint = try? handObservation.recognizedPoint(.wrist),
            
            let indexTipPoint = try? handObservation.recognizedPoint(.indexTip),
            let indexPIPPoint = try? handObservation.recognizedPoint(.indexPIP),
            
            let middleTipPoint = try? handObservation.recognizedPoint(.middleTip),
            let middlePIPPoint = try? handObservation.recognizedPoint(.middlePIP),
            
            let ringTipPoint = try? handObservation.recognizedPoint(.ringTip),
            let ringPIPPoint = try? handObservation.recognizedPoint(.ringPIP),
            
            let littleTipPoint = try? handObservation.recognizedPoint(.littleTip),
            let littlePIPPoint = try? handObservation.recognizedPoint(.littlePIP)
        else {
            return "Hand Detected"
        }
        
        // Check if confidence is high enough for all points
        let allPoints = [
            wristPoint, indexTipPoint, indexPIPPoint, middleTipPoint, middlePIPPoint,
            ringTipPoint, ringPIPPoint, littleTipPoint, littlePIPPoint
        ]
        guard allPoints.allSatisfy({ $0.confidence > 0.3 }) else {
            return "---" // Low confidence
        }
        
        // --- SIMPLIFIED GESTURE LOGIC ---
        
        let indexTipDist = distance(from: wristPoint.location, to: indexTipPoint.location)
        let indexPIPDist = distance(from: wristPoint.location, to: indexPIPPoint.location)
        
        let middleTipDist = distance(from: wristPoint.location, to: middleTipPoint.location)
        let middlePIPDist = distance(from: wristPoint.location, to: middlePIPPoint.location)
        
        let ringTipDist = distance(from: wristPoint.location, to: ringTipPoint.location)
        let ringPIPDist = distance(from: wristPoint.location, to: ringPIPPoint.location)
        
        let littleTipDist = distance(from: wristPoint.location, to: littleTipPoint.location)
        let littlePIPDist = distance(from: wristPoint.location, to: littlePIPPoint.location)

        // 1. Check for "Fist"
        // (All 4 fingers curled)
        let areAllCurled = indexTipDist < indexPIPDist && middleTipDist < middlePIPDist && ringTipDist < ringPIPDist && littleTipDist < littlePIPDist
        
        if areAllCurled {
            return "Fist"
        }
        
        // 2. Default to "Open"
        return "Open"
        // ------------------------
    }
    
    private func distance(from: CGPoint, to: CGPoint) -> CGFloat {
        let distanceX = from.x - to.x
        let distanceY = from.y - to.y
        return sqrt(distanceX * distanceX + distanceY * distanceY)
    }
}
