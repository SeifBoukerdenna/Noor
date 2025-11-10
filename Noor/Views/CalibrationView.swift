import SwiftUI

struct CalibrationView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var coordinator: CalibrationCoordinator
    @ObservedObject var cameraService: CameraService
    
    @State private var screenSize: CGSize = .zero
    
    init(cameraService: CameraService) {
        self.cameraService = cameraService
        _coordinator = StateObject(wrappedValue: CalibrationCoordinator(cameraService: cameraService))
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Black background
                Color.black
                    .ignoresSafeArea()
                
                // Target dot
                if let target = coordinator.currentTarget {
                    Circle()
                        .fill(coordinator.currentState == .capturing ? Color.green : Color.red)
                        .frame(width: 20, height: 20)
                        .position(x: target.screenX, y: target.screenY)
                        .opacity(coordinator.currentState == .paused ? 0 : 1)
                }
                
                // Progress HUD (top-left)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Target: \(coordinator.targetProgress + 1) / 10")
                        .font(.system(size: 16, weight: .bold))
                    Text("Frames: \(coordinator.capturedFrames) / 10")
                        .font(.system(size: 14))
                    Text(stateText)
                        .font(.system(size: 14))
                        .foregroundColor(stateColor)
                }
                .foregroundColor(.white)
                .padding(16)
                .background(Color.black.opacity(0.6))
                .cornerRadius(8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(20)
                .opacity(coordinator.currentState == .paused ? 0 : 1)
                
                // Prompts / Instructions
                if let prompt = coordinator.showPrompt {
                    VStack(spacing: 16) {
                        Text(prompt)
                            .font(.title2)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(32)
                        
                        if coordinator.currentState == .paused {
                            Text("Press SPACE to continue")
                                .font(.headline)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(40)
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(12)
                }
                
                // Completion screen
                if coordinator.currentState == .complete {
                    VStack(spacing: 24) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.green)
                        
                        Text("Calibration Complete!")
                            .font(.largeTitle)
                            .foregroundColor(.white)
                        
                        Text(coordinator.sessionStats)
                            .font(.body)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                        
                        Button("Close") {
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.top, 16)
                    }
                    .padding(48)
                    .background(Color.black.opacity(0.9))
                    .cornerRadius(16)
                }
                
                // Close button (top-right)
                if coordinator.currentState != .complete {
                    VStack {
                        HStack {
                            Spacer()
                            Button(action: {
                                coordinator.pauseSession()
                                dismiss()
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            .buttonStyle(.plain)
                            .padding(20)
                        }
                        Spacer()
                    }
                }
            }
            .onAppear {
                screenSize = geometry.size
                coordinator.startSession(screenSize: screenSize)
                
                // ESC key handler
                NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                    if event.keyCode == 53 { // ESC
                        coordinator.pauseSession()
                        dismiss()
                        return nil
                    }
                    if event.keyCode == 49 { // SPACE
                        if coordinator.currentState == .paused {
                            coordinator.resumeSession()
                        }
                        return nil
                    }
                    return event
                }
            }
        }
    }
    
    private var stateText: String {
        switch coordinator.currentState {
        case .ready:
            return "Ready"
        case .waitingForStability:
            return "Look at the dot..."
        case .capturing:
            return "Capturing..."
        case .paused:
            return "Paused"
        case .complete:
            return "Complete"
        }
    }
    
    private var stateColor: Color {
        switch coordinator.currentState {
        case .ready, .waitingForStability:
            return .yellow
        case .capturing:
            return .green
        case .paused:
            return .gray
        case .complete:
            return .green
        }
    }
}
