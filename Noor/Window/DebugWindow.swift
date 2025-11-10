import SwiftUI

struct DebugWindowView: View {
    @StateObject private var windowManager = WindowManager.shared
    
    let cameraService: CameraService
    let handTracker: HandTrackingService
    let gestureInterpreter: GestureInterpreter
    
    var body: some View {
        DebugView(
            cameraService: cameraService,
            handTracker: handTracker,
            gestureInterpreter: gestureInterpreter
        )
        .onAppear {
            windowManager.isDebugWindowOpen = true
        }
        .onDisappear {
            windowManager.isDebugWindowOpen = false
        }
    }
}
