import SwiftUI
import AVFoundation

// We need a special view to host the camera preview layer
struct CameraPreviewView: NSViewRepresentable {
    
    // The preview layer from our camera service
    let previewLayer: AVCaptureVideoPreviewLayer
    
    // Create the NSView
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.layer = previewLayer // Set the view's layer to our preview
        view.layer?.cornerRadius = 10 // Optional: make it look nice
        return view
    }
    
    // Update the view (not needed for this)
    func updateNSView(_ nsView: NSView, context: Context) {}
}


struct ContentView: View {
    
    // Get the ability to open other windows from the environment
    @Environment(\.openWindow) private var openWindow
    
    // Receive the shared CameraService from the main App file
    @ObservedObject var cameraService: CameraService
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Noor Control")
                .font(.headline)
                .padding(.top, 8)
            
            Divider()
            
            // This button opens the new, separate debug window
            Button("Show Debug Panel") {
                
                // --- ADD THIS LINE ---
                // This forces the app to the foreground
                NSApp.activate(ignoringOtherApps: true)
                // ---------------------
                
                // This tells SwiftUI to find and open
                // the WindowGroup with the matching ID
                openWindow(id: "debug-window")
            }
            
            Divider()
            
            // We can still show live status data here
            VStack(alignment: .leading) {
                Text("Status: \(cameraService.fps > 0 ? "Running" : "Idle")")
                    .font(.caption)
                Text("FPS: \(cameraService.fps, specifier: "%.1f")")
                    .font(.caption)
            }
            
            // A button to quit the app
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .padding(.bottom, 8)

        }
        .padding(.horizontal)
        .frame(width: 250) // A good, fixed size for a control panel
    }
}
