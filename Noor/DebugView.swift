import SwiftUI

struct DebugView: View {
    
    @ObservedObject var cameraService: CameraService
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            CameraPreviewView(previewLayer: cameraService.previewLayer)
            
            VStack(alignment: .leading) {
                Text("FPS: \(cameraService.fps, specifier: "%.1f")")
                    .font(.system(size: 12, weight: .bold))
                
                // --- UPDATED UI ---
                Text("Left Hand: \(cameraService.leftHandGesture)")
                    .font(.system(size: 12, weight: .bold))
                    // Highlight both Fist and Pinch
                    .foregroundColor(gestureColor(cameraService.leftHandGesture))
                
                Text("Right Hand: \(cameraService.rightHandGesture)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(gestureColor(cameraService.rightHandGesture))
                // ---------------
                
            }
            .padding(8)
            .background(Color.black.opacity(0.5))
            .cornerRadius(5)
            .padding(8)
        }
        .frame(minWidth: 320, minHeight: 180)
    }
    
    // --- UPDATED HELPER ---
    // This function returns a color for the active gesture
    func gestureColor(_ gesture: String) -> Color {
        switch gesture {
        case "Fist":
            return .green
        // --- REMOVED Pointing Case ---
        default:
            return .white
        }
    }
    // ------------------
}
