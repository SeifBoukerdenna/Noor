import SwiftUI

struct CalibrationView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            // Full black background
            Color.black
                .ignoresSafeArea()
            
            // Close button in top right
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                    .padding(20)
                    .help("Close Calibration (ESC)")
                }
                Spacer()
            }
            
            VStack {
                Spacer()
                
                // Instructions overlay (temporary - will be replaced with dots)
                VStack(spacing: 16) {
                    Text("Calibration Mode")
                        .font(.largeTitle)
                        .foregroundColor(.white)
                    
                    Text("Press ESC or click X to exit")
                        .font(.headline)
                        .foregroundColor(.gray)
                }
                .padding(40)
                .background(Color.black.opacity(0.7))
                .cornerRadius(12)
                
                Spacer()
            }
        }
        .onAppear {
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if event.keyCode == 53 { // ESC key
                    dismiss()
                    return nil
                }
                return event
            }
        }
    }
}
