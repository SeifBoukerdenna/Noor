import Foundation
import Combine
import AVFoundation
import AppKit

enum CalibrationState {
    case ready
    case waitingForStability
    case capturing
    case paused
    case complete
}

class CalibrationCoordinator: ObservableObject {
    
    @Published var currentState: CalibrationState = .ready
    @Published var currentTarget: CalibrationTarget?
    @Published var targetProgress: Int = 0
    @Published var capturedFrames: Int = 0
    @Published var sessionStats: String = ""
    @Published var showPrompt: String? = nil
    
    private let cameraService: CameraService
    private let dataManager = CalibrationDataManager()
    private let landmarkService = FaceLandmarkService()
    
    private var session: CalibrationSession?
    private var targets: [CalibrationTarget] = []
    private var currentTargetIndex = 0
    
    private var captureTimer: Timer?
    private var stabilityTimer: Timer?
    private var frameBuffer: [CMSampleBuffer] = []
    private var cancellables = Set<AnyCancellable>()
    private var lastFrameCaptureTime: TimeInterval = 0
    
    private let framesPerTarget = 10
    private let captureInterval: TimeInterval = 0.04 // 40ms between frames (400ms total)
    private let stabilityDuration: TimeInterval = 0.15 // 150ms stability gate
    
    private var currentTargetData: CalibrationTarget?
    private var currentFrameMetadata: [FrameMetadata] = []
    
    init(cameraService: CameraService) {
        self.cameraService = cameraService
        
        // Subscribe to camera frames
        cameraService.sampleBufferPublisher
            .sink { [weak self] buffer in
                self?.handleFrame(buffer)
            }
            .store(in: &cancellables)
    }
    
    func startSession(screenSize: CGSize) {
        session = CalibrationSession()
        targets = TargetGenerator.generateTargets(screenSize: screenSize)
        currentTargetIndex = 0
        
        do {
            try dataManager.startSession(session!)
            advanceToNextTarget()
        } catch {
            print("Failed to start session: \(error)")
        }
    }
    
    func pauseSession() {
        currentState = .paused
        cancelTimers()
    }
    
    func resumeSession() {
        if currentTarget != nil {
            startStabilityGate()
        }
    }
    
    private func advanceToNextTarget() {
        guard currentTargetIndex < targets.count else {
            completeSession()
            return
        }
        
        // Check for prompts every N targets
        if currentTargetIndex % 45 == 0 && currentTargetIndex > 0 {
            showPrompt = "Please adjust your distance: Move slightly closer/farther from the screen."
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                self.showPrompt = nil
                self.continueToNextTarget()
            }
            return
        }
        
        if currentTargetIndex % 40 == 0 && currentTargetIndex > 0 {
            showPrompt = "Break time! Press SPACE to continue."
            currentState = .paused
            return
        }
        
        continueToNextTarget()
    }
    
    private func continueToNextTarget() {
        currentTarget = targets[currentTargetIndex]
        currentTargetData = currentTarget
        targetProgress = currentTargetIndex
        capturedFrames = 0
        currentFrameMetadata = []
        frameBuffer = []
        
        startStabilityGate()
    }
    
    private func startStabilityGate() {
        currentState = .waitingForStability
        
        // After stability duration, start capture
        stabilityTimer = Timer.scheduledTimer(withTimeInterval: stabilityDuration, repeats: false) { [weak self] _ in
            self?.startCapture()
        }
    }
    
    private func startCapture() {
        currentState = .capturing
        capturedFrames = 0
        frameBuffer = []
    }
    
    private func handleFrame(_ buffer: CMSampleBuffer) {
        guard currentState == .capturing else { return }
        guard capturedFrames < framesPerTarget else {
            if capturedFrames == framesPerTarget {
                DispatchQueue.main.async {
                    self.finishTarget()
                }
            }
            return
        }
        
        // Throttle to 40ms between frames
        let now = Date().timeIntervalSince1970
        guard now - lastFrameCaptureTime >= captureInterval else { return }
        lastFrameCaptureTime = now
        
        do {
            let result = try landmarkService.processFrame(buffer)
            
            guard let target = currentTargetData else { return }
            
            let metadata = FrameMetadata(
                frameIndex: capturedFrames,
                timestamp: now,
                screenX: target.screenX,
                screenY: target.screenY,
                normalizedX: target.normalizedX,
                normalizedY: target.normalizedY,
                lidGap: result.lidGap,
                interPupilDistance: result.interPupilDistance,
                distanceProxy: result.distanceProxy,
                poseFeatures: result.poseFeatures,
                usable: result.usable,
                blurScore: 0.0,
                leftEyeROI: result.leftROI,
                rightEyeROI: result.rightROI
            )
            
            // Save frame
            try dataManager.saveFrame(
                targetID: target.targetID,
                frameIndex: capturedFrames,
                leftEye: result.leftEye,
                rightEye: result.rightEye,
                metadata: metadata
            )
            
            currentFrameMetadata.append(metadata)
            
            DispatchQueue.main.async {
                self.capturedFrames += 1
            }
            
            print("Captured frame \(capturedFrames) for target \(target.targetID)")
            
        } catch {
            print("Frame processing error: \(error)")
        }
    }
    
    private func finishTarget() {
        cancelTimers()
        
        guard var target = currentTargetData else { return }
        
        // Update target with captured data
        let usableCount = currentFrameMetadata.filter { $0.usable }.count
        let avgLidGap = currentFrameMetadata.map { $0.lidGap }.reduce(0, +) / CGFloat(max(currentFrameMetadata.count, 1))
        let avgDist = currentFrameMetadata.map { $0.distanceProxy }.reduce(0, +) / CGFloat(max(currentFrameMetadata.count, 1))
        
        target.capturedFrames = currentFrameMetadata.count
        target.usableFrames = usableCount
        target.averageLidGap = avgLidGap
        target.averageDistanceProxy = avgDist
        
        do {
            try dataManager.saveTarget(target)
        } catch {
            print("Failed to save target: \(error)")
        }
        
        // Check if we need to retry (less than 8 usable frames)
        if usableCount < 8 {
            print("Retrying target \(target.targetID) - only \(usableCount) usable frames")
            currentFrameMetadata = []
            startStabilityGate()
            return
        }
        
        // Advance to next target
        currentTargetIndex += 1
        advanceToNextTarget()
    }
    
    private func completeSession() {
        currentState = .complete
        cancelTimers()
        
        // Count from saved targets, not the initial array
        let totalCaptured = currentTargetIndex * framesPerTarget
        print("📊 Session complete - processed \(currentTargetIndex) targets")
        
        sessionStats = "Calibration session saved! Check console for file location."
        
        if let sessionURL = dataManager.getSessionURL() {
            print("📁 Session data: \(sessionURL.path)")
        }
    }
    
    private func cancelTimers() {
        captureTimer?.invalidate()
        stabilityTimer?.invalidate()
        captureTimer = nil
        stabilityTimer = nil
    }
}
