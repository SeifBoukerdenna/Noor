import Foundation
import CoreGraphics
import Combine

class SystemCommandExecutor: ObservableObject {
    
    private var cancellables = Set<AnyCancellable>()
    private var cmdKeyHeld = false

    init(actionMapper: ActionMapper) {
        actionMapper.actionPublisher
            .sink { [weak self] action in
                self?.execute(action)
            }
            .store(in: &cancellables)
    }
    
    private func execute(_ action: AppAction) {
        switch action {
        case .confirm:
            print("Executing: Enter Key")
            postKeyEvent(keyCode: 0x24, flags: [])
            
        case .appSwitcher:
            
            print("Executing: Hold Cmd + Press Tab (legacy)")
            holdCmdAndPressTab()
            
        case .appSwitcherStart:
            print("Executing: Hold Cmd + Press Tab")
            holdCmdAndPressTab()
            
        case .appSwitcherDrop:
            print("Executing: Release Cmd")
            releaseCmdKey()
            
        case .appSwitcherCycle:
            print("Executing: Press Tab (while Cmd held)")
            if cmdKeyHeld {
                postKeyEvent(keyCode: 0x30, flags: [.maskCommand])
            }
            
        case .scrollUp:
            print("Executing: Scroll Up")
            postScrollEvent(deltaY: 3)
            
        case .scrollDown:
            print("Executing: Scroll Down")
            postScrollEvent(deltaY: -3)
            
        case .none:
            break
        }
    }
    
    private func holdCmdAndPressTab() {
        // Hold Cmd key down
        if let cmdDownEvent = CGEvent(keyboardEventSource: nil, virtualKey: 0x37, keyDown: true) {
            cmdDownEvent.post(tap: .cghidEventTap)
            cmdKeyHeld = true
        }
        
        // Press Tab
        postKeyEvent(keyCode: 0x30, flags: [.maskCommand])
    }
    
    private func releaseCmdKey() {
        guard cmdKeyHeld else { return }
        
        if let cmdUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: 0x37, keyDown: false) {
            cmdUpEvent.post(tap: .cghidEventTap)
            cmdKeyHeld = false
        }
    }

    private func postScrollEvent(deltaY: Int32) {
        guard let scrollEvent = CGEvent(scrollWheelEvent2Source: nil,
                                        units: .line,
                                        wheelCount: 1,
                                        wheel1: deltaY,
                                        wheel2: 0,
                                        wheel3: 0) else {
            print("Failed to create scroll event")
            return
        }
        scrollEvent.post(tap: .cgSessionEventTap)
    }
    
    private func postKeyEvent(keyCode: CGKeyCode, flags: CGEventFlags) {
        let downEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true)
        downEvent?.flags = flags
        downEvent?.post(tap: .cghidEventTap)
        
        let upEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)
        upEvent?.flags = flags
        upEvent?.post(tap: .cghidEventTap)
    }
}
