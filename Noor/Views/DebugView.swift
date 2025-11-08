import SwiftUI

struct DebugView: View {
    
    @ObservedObject var cameraService: CameraService
    @ObservedObject var handTracker: HandTrackingService
    @ObservedObject var gestureInterpreter: GestureInterpreter
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            CameraPreviewView(previewLayer: cameraService.previewLayer)
            
            VStack(alignment: .leading) {
                Text("FPS: \(handTracker.fps, specifier: "%.1f")")
                    .font(.system(size: 12, weight: .bold))
                
                let leftGesture = gestureInterpreter.leftHandState?.staticGesture.rawValue ?? "---"
                let leftMotion = gestureInterpreter.leftHandState?.dynamicGesture.rawValue ?? "---"
                let rightGesture = gestureInterpreter.rightHandState?.staticGesture.rawValue ?? "---"
                let rightMotion = gestureInterpreter.rightHandState?.dynamicGesture.rawValue ?? "---"
                let rightPalm = gestureInterpreter.rightHandState?.palmOrientation.rawValue ?? "---"

                Text("Left Hand: \(leftGesture)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(gestureColor(leftGesture))
                
                Text("Left Motion: \(leftMotion)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(motionColor(leftMotion))
                
                Text("Right Hand: \(rightGesture)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(gestureColor(rightGesture))
                
                Text("Right Motion: \(rightMotion)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(motionColor(rightMotion))
                
                Text("Right Palm: \(rightPalm)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(palmColor(rightPalm))
            }
            .padding(8)
            .background(Color.black.opacity(0.5))
            .cornerRadius(5)
            .padding(8)
        }
        .frame(minWidth: 320, minHeight: 180)
    }
    
    func gestureColor(_ gesture: String) -> Color {
        switch gesture {
        case "Fist":
            return .green
        case "Pinch":
            return .purple
        default:
            return .white
        }
    }
    
    func motionColor(_ motion: String) -> Color {
        switch motion {
        case "Up":
            return .cyan
        case "Down":
            return .orange
        default:
            return .white
        }
    }
    
    func palmColor(_ palm: String) -> Color {
        switch palm {
        case "→ Screen":
            return .green
        case "← Away":
            return .red
        default:
            return .white
        }
    }
}
