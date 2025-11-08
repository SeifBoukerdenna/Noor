import Foundation
import Combine

class ActionMapper: ObservableObject {
    
    let actionPublisher = PassthroughSubject<AppAction, Never>()
    
    // App Switcher State
    private var appSwitcherActive = false
    private var palmFacingScreenStartTime: TimeInterval?
    private let palmActivationDelay: TimeInterval = 0.3 // Hold palm facing for 300ms to activate
    private let palmDropGracePeriod: TimeInterval = 0.3 // Allow 300ms flicker before dropping
    private var palmLastSeenTime: TimeInterval?
    
    // Pinch State
    private var lastPinchTime: TimeInterval = 0
    private let pinchCooldown: TimeInterval = 0.4
    
    // Confirm State
    private var isLeftFistDown = false
    private let gestureCooldown: TimeInterval = 0.5
    private var lastLeftActionTime: TimeInterval = 0
    
    // Scroll State
    private let scrollCooldown: TimeInterval = 0.15
    private var lastLeftScrollTime: TimeInterval = 0
    private var lastRightScrollTime: TimeInterval = 0
        
    private var cancellables = Set<AnyCancellable>()

    init(interpreter: GestureInterpreter) {
        interpreter.$leftHandState
            .sink { [weak self] state in
                self?.handleLeftHand(state)
            }
            .store(in: &cancellables)
    
        interpreter.$rightHandState
            .sink { [weak self] state in
                self?.handleRightHand(state)
            }
            .store(in: &cancellables)
    }
    
    private func handleRightHand(_ state: HandState?) {
        let currentTime = Date.timeIntervalSinceReferenceDate
        
        guard let state = state else {
            // Right hand lost - check if we should drop app switcher
            if appSwitcherActive {
                if let lastSeen = palmLastSeenTime, currentTime - lastSeen > palmDropGracePeriod {
                    print("Mapping: Right Hand Lost -> Drop App Switcher")
                    actionPublisher.send(.appSwitcherDrop)
                    appSwitcherActive = false
                    palmFacingScreenStartTime = nil
                    palmLastSeenTime = nil
                }
            }
            return
        }
        
        // Track palm orientation
        if state.palmOrientation == .facingScreen {
            palmLastSeenTime = currentTime
            
            if !appSwitcherActive {
                // Start tracking palm facing duration
                if palmFacingScreenStartTime == nil {
                    palmFacingScreenStartTime = currentTime
                } else if currentTime - palmFacingScreenStartTime! >= palmActivationDelay {
                    print("Mapping: Right Palm Facing Screen -> Start App Switcher")
                    actionPublisher.send(.appSwitcherStart)
                    appSwitcherActive = true
                }
            }
        } else {
            // Palm not facing screen
            palmFacingScreenStartTime = nil
            
            if appSwitcherActive {
                // Check grace period
                if let lastSeen = palmLastSeenTime, currentTime - lastSeen > palmDropGracePeriod {
                    print("Mapping: Right Palm Away -> Drop App Switcher")
                    actionPublisher.send(.appSwitcherDrop)
                    appSwitcherActive = false
                    palmLastSeenTime = nil
                }
            }
        }
        
        // Scroll with right hand (when app switcher is not active)
        if !appSwitcherActive && currentTime - lastRightScrollTime > scrollCooldown {
            let motion = state.dynamicGesture
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
    
    private func handleLeftHand(_ state: HandState?) {
        let currentTime = Date.timeIntervalSinceReferenceDate
        
        guard let state = state else { return }
        
        // Pinch to cycle (only when app switcher is active)
        if appSwitcherActive && state.staticGesture == .pinch {
            if currentTime - lastPinchTime > pinchCooldown {
                print("Mapping: Left Pinch -> Cycle App")
                actionPublisher.send(.appSwitcherCycle)
                lastPinchTime = currentTime
            }
        }
        
        // Fist to confirm (when app switcher is not active)
        if !appSwitcherActive {
            let isFist = (state.staticGesture == .fist)
            
            if isFist && !isLeftFistDown && currentTime - lastLeftActionTime > gestureCooldown {
                print("Mapping: Left Fist -> Confirm")
                actionPublisher.send(.confirm)
                lastLeftActionTime = currentTime
            }
            isLeftFistDown = isFist
        }
        
        // Scroll with left hand (when app switcher is not active)
        if !appSwitcherActive && currentTime - lastLeftScrollTime > scrollCooldown {
            let motion = state.dynamicGesture
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
    }
}
