import SwiftUI

@main
struct NoorApp: App {
    
    // Create the CameraService here as a StateObject.
    // This makes it a "singleton" for the whole app.
    @StateObject private var cameraService = CameraService()
    
    var body: some Scene {
        
        // --- This is your Menu Bar Icon ---
        MenuBarExtra("Noor", systemImage: "eye.fill") {
            
            // Pass the single camera service to the popover view
            ContentView(cameraService: cameraService)
            
        }
        .menuBarExtraStyle(.window)
        
        
        // --- This is your NEW Debug Window ---
        WindowGroup("Debug Panel", id: "debug-window") {
            
            // Pass the SAME camera service to the debug view
            DebugView(cameraService: cameraService)
        }
        // --- ADD THIS MODIFIER ---
        // This tells the window to float on top of others
        .windowLevel(.floating)
        // -------------------------
    }
}
