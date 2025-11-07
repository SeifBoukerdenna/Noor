import SwiftUI

@main
struct NoorApp: App {
    
    // We create both of our services here as StateObjects
    // This ensures they are created once and shared
    @StateObject private var cameraService: CameraService
    @StateObject private var inputController: InputController

    // We use a custom init to connect them
    init() {
        // 1. Create the single CameraService instance
        let service = CameraService()
        
        // 2. Initialize the @StateObject for the camera
        _cameraService = StateObject(wrappedValue: service)
        
        // 3. Initialize the @StateObject for the controller,
        //    passing it the service we just made.
        _inputController = StateObject(wrappedValue: InputController(cameraService: service))
    }

    var body: some Scene {
        
        // This is your Menu Bar Icon
        MenuBarExtra("Noor", systemImage: "eye.fill") {
            // Pass the single, shared service to the popover view
            ContentView(cameraService: cameraService)
        }
        .menuBarExtraStyle(.window)
        
        
        // This is your separate Debug Window
        WindowGroup("Debug Panel", id: "debug-window") {
            // Pass the SAME shared service to the debug view
            DebugView(cameraService: cameraService)
        }
        .windowLevel(.floating) // Makes the window float on top
    }
}
