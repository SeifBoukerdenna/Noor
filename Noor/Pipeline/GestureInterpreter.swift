import Vision
import Combine
import SwiftUI

class GestureInterpreter: ObservableObject {
    
    @Published var leftHandState: HandState?
    @Published var rightHandState: HandState?

    private var leftHandYPositions: [CGFloat] = []
    private var rightHandYPositions: [CGFloat] = []
    private let positionHistorySize = 12
    private let motionThreshold: CGFloat = 0.08
    private let averagingWindow = 4
    private let minHistoryForDetection = 8
    
    private var cancellables = Set<AnyCancellable>()

    init(handTracker: HandTrackingService) {
        handTracker.handObservationsPublisher
            .sink { [weak self] observations in
                self?.interpret(observations)
            }
            .store(in: &cancellables)
    }
    
    private func interpret(_ observations: [VNHumanHandPoseObservation]) {
        var newLeft: HandState?
        var newRight: HandState?

        for hand in observations {
            let chirality: HandChirality = (hand.chirality == .left) ? .left : .right
            let staticGesture = detectGesture(from: hand)
            let dynamicGesture = detectMotion(from: hand, handedness: chirality)
            let palmOrientation = detectPalmOrientation(from: hand)
            
            let state = HandState(
                chirality: chirality,
                staticGesture: staticGesture,
                dynamicGesture: dynamicGesture,
                palmOrientation: palmOrientation
            )
            
            if chirality == .left { newLeft = state }
            else { newRight = state }
        }
        
        if newLeft == nil { leftHandYPositions.removeAll() }
        if newRight == nil { rightHandYPositions.removeAll() }

        DispatchQueue.main.async {
            self.leftHandState = newLeft
            self.rightHandState = newRight
        }
    }
    
    private func detectMotion(from handObservation: VNHumanHandPoseObservation, handedness: HandChirality) -> DynamicGesture {
        guard let wristPoint = try? handObservation.recognizedPoint(.wrist),
              wristPoint.confidence > 0.3 else {
            return .stationary
        }
        
        let wristY = wristPoint.location.y
        
        if handedness == .left {
            leftHandYPositions.append(wristY)
            if leftHandYPositions.count > positionHistorySize {
                leftHandYPositions.removeFirst()
            }
            
            guard leftHandYPositions.count >= minHistoryForDetection else { return .stationary }
            
            let avgStart = leftHandYPositions.prefix(averagingWindow).reduce(0, +) / CGFloat(averagingWindow)
            let avgEnd = leftHandYPositions.suffix(averagingWindow).reduce(0, +) / CGFloat(averagingWindow)
            let delta = avgEnd - avgStart
            
            if delta > motionThreshold {
                return .movingUp
            } else if delta < -motionThreshold {
                return .movingDown
            }
            
        } else if handedness == .right {
            rightHandYPositions.append(wristY)
            if rightHandYPositions.count > positionHistorySize {
                rightHandYPositions.removeFirst()
            }
            
            guard rightHandYPositions.count >= minHistoryForDetection else { return .stationary }
            
            let avgStart = rightHandYPositions.prefix(averagingWindow).reduce(0, +) / CGFloat(averagingWindow)
            let avgEnd = rightHandYPositions.suffix(averagingWindow).reduce(0, +) / CGFloat(averagingWindow)
            let delta = avgEnd - avgStart
            
            if delta > motionThreshold {
                return .movingUp
            } else if delta < -motionThreshold {
                return .movingDown
            }
        }
        
        return .stationary
    }
    
    private func detectPalmOrientation(from handObservation: VNHumanHandPoseObservation) -> PalmOrientation {
        guard
            let wristPoint = try? handObservation.recognizedPoint(.wrist),
            let middleMCPPoint = try? handObservation.recognizedPoint(.middleMCP),
            wristPoint.confidence > 0.3,
            middleMCPPoint.confidence > 0.3
        else {
            return .neutral
        }
        
        // Vector from wrist to middle MCP (palm center direction)
        let palmVector = CGPoint(
            x: middleMCPPoint.location.x - wristPoint.location.x,
            y: middleMCPPoint.location.y - wristPoint.location.y
        )
        
        // In Vision framework coordinates (0,0 is bottom-left):
        // If palm vector points "up" (positive Y), palm is facing screen
        // If palm vector points "down" (negative Y), palm is facing away
        
        let orientationThreshold: CGFloat = 0.05
        
        if palmVector.y > orientationThreshold {
            return .facingScreen
        } else if palmVector.y < -orientationThreshold {
            return .facingAway
        }
        
        return .neutral
    }
    
    private func detectGesture(from handObservation: VNHumanHandPoseObservation) -> StaticGesture {
        guard
            let wristPoint = try? handObservation.recognizedPoint(.wrist),
            let thumbTip = try? handObservation.recognizedPoint(.thumbTip),
            let indexTipPoint = try? handObservation.recognizedPoint(.indexTip),
            let indexPIPPoint = try? handObservation.recognizedPoint(.indexPIP),
            let middleTipPoint = try? handObservation.recognizedPoint(.middleTip),
            let middlePIPPoint = try? handObservation.recognizedPoint(.middlePIP),
            let ringTipPoint = try? handObservation.recognizedPoint(.ringTip),
            let ringPIPPoint = try? handObservation.recognizedPoint(.ringPIP),
            let littleTipPoint = try? handObservation.recognizedPoint(.littleTip),
            let littlePIPPoint = try? handObservation.recognizedPoint(.littlePIP)
        else {
            return .unknown
        }
        
        let allPoints = [
            wristPoint, thumbTip, indexTipPoint, indexPIPPoint, middleTipPoint, middlePIPPoint,
            ringTipPoint, ringPIPPoint, littleTipPoint, littlePIPPoint
        ]
        guard allPoints.allSatisfy({ $0.confidence > 0.3 }) else {
            return .unknown
        }
        
        // PINCH: Thumb tip + Index tip close together
        // CRITICAL: Require high confidence to avoid false positives when hand exits frame
        let thumbIndexDistance = distance(from: thumbTip.location, to: indexTipPoint.location)
        let pinchThreshold: CGFloat = 0.05
        
        if thumbIndexDistance < pinchThreshold {
            // Extra validation: require HIGH confidence for pinch landmarks
            guard thumbTip.confidence > 0.7 && indexTipPoint.confidence > 0.7 else {
                return .unknown
            }
            
            // Validate other fingers are extended (not curled like a fist)
            let middleTipDist = distance(from: wristPoint.location, to: middleTipPoint.location)
            let middlePIPDist = distance(from: wristPoint.location, to: middlePIPPoint.location)
            let ringTipDist = distance(from: wristPoint.location, to: ringTipPoint.location)
            let ringPIPDist = distance(from: wristPoint.location, to: ringPIPPoint.location)
            
            // Other fingers should be extended (tip farther than PIP)
            let openThreshold: CGFloat = 0.95 // Tip should be at least as far as PIP
            let areOtherFingersExtended = middleTipDist > middlePIPDist * openThreshold &&
                                          ringTipDist > ringPIPDist * openThreshold
            
            if areOtherFingersExtended {
                return .pinch
            }
        }
        
        // FIST: All fingers curled
        let indexTipDist = distance(from: wristPoint.location, to: indexTipPoint.location)
        let indexPIPDist = distance(from: wristPoint.location, to: indexPIPPoint.location)
        
        let middleTipDist = distance(from: wristPoint.location, to: middleTipPoint.location)
        let middlePIPDist = distance(from: wristPoint.location, to: middlePIPPoint.location)
        
        let ringTipDist = distance(from: wristPoint.location, to: ringTipPoint.location)
        let ringPIPDist = distance(from: wristPoint.location, to: ringPIPPoint.location)
        
        let littleTipDist = distance(from: wristPoint.location, to: littleTipPoint.location)
        let littlePIPDist = distance(from: wristPoint.location, to: littlePIPPoint.location)

        let fistMargin: CGFloat = 0.85
        let areAllCurled = indexTipDist < indexPIPDist * fistMargin &&
                           middleTipDist < middlePIPDist * fistMargin &&
                           ringTipDist < ringPIPDist * fistMargin &&
                           littleTipDist < littlePIPDist * fistMargin
        
        if areAllCurled {
            return .fist
            
            
        }
        
        return .open
    }
    
    private func distance(from: CGPoint, to: CGPoint) -> CGFloat {
        let distanceX = from.x - to.x
        let distanceY = from.y - to.y
        return sqrt(distanceX * distanceX + distanceY * distanceY)
    }
}
