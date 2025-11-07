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
            let staticGesture = detectFist(from: hand)
            let dynamicGesture = detectMotion(from: hand, handedness: chirality)
            
            let state = HandState(chirality: chirality, staticGesture: staticGesture, dynamicGesture: dynamicGesture)
            
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
    
    private func detectFist(from handObservation: VNHumanHandPoseObservation) -> StaticGesture {
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
            return .unknown
        }
        
        let allPoints = [
            wristPoint, indexTipPoint, indexPIPPoint, middleTipPoint, middlePIPPoint,
            ringTipPoint, ringPIPPoint, littleTipPoint, littlePIPPoint
        ]
        guard allPoints.allSatisfy({ $0.confidence > 0.3 }) else {
            return .unknown // Low confidence
        }
        
        let indexTipDist = distance(from: wristPoint.location, to: indexTipPoint.location)
        let indexPIPDist = distance(from: wristPoint.location, to: indexPIPPoint.location)
        
        let middleTipDist = distance(from: wristPoint.location, to: middleTipPoint.location)
        let middlePIPDist = distance(from: wristPoint.location, to: middlePIPPoint.location)
        
        let ringTipDist = distance(from: wristPoint.location, to: ringTipPoint.location)
        let ringPIPDist = distance(from: wristPoint.location, to: ringPIPPoint.location)
        
        let littleTipDist = distance(from: wristPoint.location, to: littleTipPoint.location)
        let littlePIPDist = distance(from: wristPoint.location, to: littlePIPPoint.location)

        let fistMargin: CGFloat = 0.85 // Tip must be at least 15% closer
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

