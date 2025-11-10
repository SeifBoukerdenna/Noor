import SwiftUI

@main
struct NoorApp: App {
    
    @StateObject private var cameraService: CameraService
    @StateObject private var handTracker: HandTrackingService
    @StateObject private var gestureInterpreter: GestureInterpreter
    @StateObject private var actionMapper: ActionMapper
    @StateObject private var commandExecutor: SystemCommandExecutor
    
    init() {
    
        let cs = CameraService()
        let ht = HandTrackingService(cameraService: cs)
        let gi = GestureInterpreter(handTracker: ht)
        let am = ActionMapper(interpreter: gi)
        let ce = SystemCommandExecutor(actionMapper: am)
        
        _cameraService = StateObject(wrappedValue: cs)
        _handTracker = StateObject(wrappedValue: ht)
        _gestureInterpreter = StateObject(wrappedValue: gi)
        _actionMapper = StateObject(wrappedValue: am)
        _commandExecutor = StateObject(wrappedValue: ce)
    }

    var body: some Scene {
        
        MenuBarExtra("Noor", systemImage: "eye.fill") {
            ContentView(cameraService: cameraService, handTracker: handTracker)
        }
        .menuBarExtraStyle(.window)
        
        Window("Debug Panel", id: "debug-window") {
            DebugView(
                cameraService: cameraService,
                handTracker: handTracker,
                gestureInterpreter: gestureInterpreter
            )
        }
        .windowLevel(.floating)
        
        Window("Calibration", id: "calibration-window") {
            CalibrationView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .windowLevel(.floating)
        .defaultSize(width: NSScreen.main?.frame.width ?? 1920,
                     height: NSScreen.main?.frame.height ?? 1080)
    }
}
