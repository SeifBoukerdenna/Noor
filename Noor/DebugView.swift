import SwiftUI

struct DebugView: View {
    
    // This view will be GIVEN the camera service
    @ObservedObject var cameraService: CameraService
    
    var body: some View {
        // Use a ZStack to overlay content
        ZStack(alignment: .bottomLeading) {
            
            // Layer 1: The camera preview
            CameraPreviewView(previewLayer: cameraService.previewLayer)
            
            // Layer 2: The debug panel
            VStack(alignment: .leading) {
                Text("FPS: \(cameraService.fps, specifier: "%.1f")")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
            }
            .padding(8)
            .background(Color.black.opacity(0.5))
            .cornerRadius(5)
            .padding(8)
            
        }
        // Give the window a default size
        .frame(minWidth: 320, minHeight: 180)
    }
}
