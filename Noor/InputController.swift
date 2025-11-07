import Foundation
import Combine
import CoreGraphics

class InputController: ObservableObject {
    
    private var cameraService: CameraService
    private var cancellables = Set<AnyCancellable>()
    
    // --- State variables to detect the "rising edge" of a gesture ---
    private var isLeftFistDown = false
    private var isRightFistDown = false
    // --- REMOVED Pointing properties ---
    
    // --- Cooldown Properties ---
    private let gestureCooldown: TimeInterval = 0.5
    private var lastLeftActionTime: TimeInterval = 0
    private var lastRightActionTime: TimeInterval = 0
    // --------------------------------
    
    init(cameraService: CameraService) {
        self.cameraService = cameraService
        
        cameraService.$leftHandGesture
            .sink { [weak self] gesture in
                self?.handleGesture(gesture, hand: .left)
            }
            .store(in: &cancellables)
        
        cameraService.$rightHandGesture
            .sink { [weak self] gesture in
                self?.handleGesture(gesture, hand: .right)
            }
            .store(in: &cancellables)
    }
    
    private enum Hand {
        case left, right
    }
    
    private func handleGesture(_ gesture: String, hand: Hand) {
        let isFist = (gesture == "Fist")
        // --- REMOVED isPointing ---
        
        let currentTime = Date.timeIntervalSinceReferenceDate
        // ----------------------------------------------
        
        if hand == .left {
            if currentTime - lastLeftActionTime > gestureCooldown {
                
                // --- REMOVED Pointing block ---

                // --- UPDATED: Left Fist now triggers "Enter" ---
                if isFist && !isLeftFistDown {
                    print("Left Fist Detected! Triggering Enter")
                    postKeyEvent(keyCode: 0x24, flags: []) // 0x24 is "Enter" (Return) key
                    lastLeftActionTime = currentTime // <-- Start cooldown
                }
                // ------------------------------------------
            }
            
            // Update state regardless of cooldown
            // --- REMOVED isLeftPointingDown ---
            isLeftFistDown = isFist
            
        } else if hand == .right {
            
            if currentTime - lastRightActionTime > gestureCooldown {
                
                // Handle Right Fist for "Cmd+Tab" (This is unchanged)
                if isFist && !isRightFistDown {
                    print("Right Fist Detected! Triggering Cmd+Tab")
                    postKeyEvent(keyCode: 0x30, flags: [.maskCommand]) // 0x30 is "Tab"
                    lastRightActionTime = currentTime // <-- Start cooldown
                }
                
                // --- REMOVED Pointing block ---
            }
            
            // Update state regardless of cooldown
            isRightFistDown = isFist
            // --- REMOVED isRightPointingDown ---
        }
    }
    
    // This is the low-level function that simulates a key press
    private func postKeyEvent(keyCode: CGKeyCode, flags: CGEventFlags) {
        let downEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true)
        downEvent?.flags = flags
        downEvent?.post(tap: .cghidEventTap)
        
        // Release the key
        let upEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)
        upEvent?.flags = flags
        upEvent?.post(tap: .cghidEventTap)
    }
}
