import AVFoundation
import SwiftUI // Import SwiftUI to get access to @Published

// Make the class conform to AVCaptureVideoDataOutputSampleBufferDelegate
class CameraService: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    let session = AVCaptureSession()
    @Published var previewLayer: AVCaptureVideoPreviewLayer!
    
    // --- NEW PROPERTIES ---
    @Published var fps: Double = 0.0
    private var frameCount: Int = 0
    private var lastTimestamp = Date.timeIntervalSinceReferenceDate
    // ----------------------
    
    override init() {
        super.init()
        
        self.previewLayer = AVCaptureVideoPreviewLayer(session: self.session)
        self.previewLayer.videoGravity = .resizeAspectFill
        
        checkCameraPermission()
    }
    
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
            break
        @unknown default:
            break
        }
    }
    
    private func setupCamera() {
        guard let videoDevice = AVCaptureDevice.default(for: .video) else { return }
        
        do {
            let input = try AVCaptureDeviceInput(device: videoDevice)
            if session.canAddInput(input) {
                session.addInput(input)
            }
            
            // --- NEW CODE: Add Video Data Output ---
            let videoOutput = AVCaptureVideoDataOutput()
            // Set the delegate to self and create a queue for processing frames
            videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoDataQueue", qos: .userInitiated))
            
            if session.canAddOutput(videoOutput) {
                session.addOutput(videoOutput)
            }
            // -------------------------------------
            
            DispatchQueue.global(qos: .userInitiated).async {
                self.session.startRunning()
            }
            
        } catch {
            print("Error setting up camera: \(error)")
        }
    }
    
    // --- NEW METHOD: This delegate function is called for EVERY frame ---
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        // This is where all of Pillar 1's logic will go.
        // For now, let's just calculate FPS.
        
        let currentTime = Date.timeIntervalSinceReferenceDate
        frameCount += 1
        
        let elapsedTime = currentTime - lastTimestamp
        
        // Update FPS roughly every second
        if elapsedTime >= 1.0 {
            let newFPS = Double(frameCount) / elapsedTime
            
            // Update the @Published property on the main thread
            DispatchQueue.main.async {
                self.fps = newFPS
            }
            
            // Reset for next calculation
            frameCount = 0
            lastTimestamp = currentTime
        }
        
        // We will eventually pass this 'sampleBuffer' to MediaPipe
    }
    // -----------------------------------------------------------------
}
