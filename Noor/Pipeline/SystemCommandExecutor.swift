import Foundation
import CoreGraphics
import Combine

class SystemCommandExecutor: ObservableObject {
    
    private var cancellables = Set<AnyCancellable>()

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
            postKeyEvent(keyCode: 0x24, flags: []) // Enter
        case .appSwitcher:
            print("Executing: Cmd+Tab")
            postKeyEvent(keyCode: 0x30, flags: [.maskCommand]) // Tab
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
