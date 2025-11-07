import Foundation
import Combine

class ActionMapper: ObservableObject {
    
    let actionPublisher = PassthroughSubject<AppAction, Never>()
    
    private var isLeftFistDown = false
    private var isRightFistDown = false
    
    private let gestureCooldown: TimeInterval = 0.5
    private var lastLeftActionTime: TimeInterval = 0
    private var lastRightActionTime: TimeInterval = 0
    
    private let scrollCooldown: TimeInterval = 0.15
    private var lastLeftScrollTime: TimeInterval = 0
    private var lastRightScrollTime: TimeInterval = 0
        
    private var cancellables = Set<AnyCancellable>()

    init(interpreter: GestureInterpreter) {
        interpreter.$leftHandState
            .sink { [weak self] state in
                self?.handleState(state, hand: .left)
            }
            .store(in: &cancellables)
    
        interpreter.$rightHandState
            .sink { [weak self] state in
                self?.handleState(state, hand: .right)
            }
            .store(in: &cancellables)
    }
    
    private func handleState(_ state: HandState?, hand: HandChirality) {
        let currentTime = Date.timeIntervalSinceReferenceDate
        
        let isFist = (state?.staticGesture == .fist)
        
        if hand == .left {
            if isFist && !isLeftFistDown && (currentTime - lastLeftActionTime > gestureCooldown) {
                print("Mapping: Left Fist -> Confirm")
                actionPublisher.send(.confirm)
                lastLeftActionTime = currentTime
            }
            isLeftFistDown = isFist
        } else {
            if isFist && !isRightFistDown && (currentTime - lastRightActionTime > gestureCooldown) {
                print("Mapping: Right Fist -> AppSwitcher")
                actionPublisher.send(.appSwitcher)
                lastRightActionTime = currentTime
            }
            isRightFistDown = isFist
        }
        
        let motion = state?.dynamicGesture ?? .stationary
        
        if hand == .left {
            if (currentTime - lastLeftScrollTime > scrollCooldown) {
                if motion == .movingUp {
                    print("Mapping: Left Up -> Scroll Down")
                    actionPublisher.send(.scrollDown)
                    lastLeftScrollTime = currentTime
                } else if motion == .movingDown {
                    print("Mapping: Left Down -> Scroll Up")
                    actionPublisher.send(.scrollUp)
                    lastLeftScrollTime = currentTime
                }
            }
        } else {
             if (currentTime - lastRightScrollTime > scrollCooldown) {
                if motion == .movingUp {
                    print("Mapping: Right Up -> Scroll Down")
                    actionPublisher.send(.scrollDown)
                    lastRightScrollTime = currentTime
                } else if motion == .movingDown {
                    print("Mapping: Right Down -> Scroll Up")
                    actionPublisher.send(.scrollUp)
                    lastRightScrollTime = currentTime
                }
            }
        }
    }
}
