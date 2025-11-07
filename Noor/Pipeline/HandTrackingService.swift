import Vision
import Combine
import AVFoundation
import SwiftUI

class HandTrackingService: ObservableObject {
    
    @Published var fps: Double = 0.0
    
    let handObservationsPublisher = PassthroughSubject<[VNHumanHandPoseObservation], Never>()
    
    private var handPoseRequest = VNDetectHumanHandPoseRequest()
    private var cancellables = Set<AnyCancellable>()
    
    private var frameCount: Int = 0
    private var lastTimestamp = Date.timeIntervalSinceReferenceDate
    
    init(cameraService: CameraService) {
        handPoseRequest.maximumHandCount = 2
    
        cameraService.sampleBufferPublisher
            .sink { [weak self] buffer in
                self?.processFrame(buffer)
            }
            .store(in: &cancellables)
    }
    
    private func processFrame(_ sampleBuffer: CMSampleBuffer) {
        let currentTime = Date.timeIntervalSinceReferenceDate
        frameCount += 1
        let elapsedTime = currentTime - lastTimestamp
        
        if elapsedTime >= 1.0 {
            let newFPS = Double(frameCount) / elapsedTime
            DispatchQueue.main.async { self.fps = newFPS }
            frameCount = 0
            lastTimestamp = currentTime
        }
        
        do {
            let handler = VNImageRequestHandler(cmSampleBuffer: sampleBuffer, orientation: .up, options: [:])
            try handler.perform([handPoseRequest])
            
            if let results = handPoseRequest.results {
                handObservationsPublisher.send(results)
            } else {
                handObservationsPublisher.send([])
            }
        } catch {
            handObservationsPublisher.send([])
        }
    }
}
