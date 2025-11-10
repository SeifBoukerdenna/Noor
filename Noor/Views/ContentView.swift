//
//  ContentView.swift
//  Noor
//
//  Created by Gemini on 2025-11-07.
//

import SwiftUI
import AVFoundation


struct ContentView: View {
    @Environment(\.openWindow) private var openWindow
    
    @ObservedObject var cameraService: CameraService
    @ObservedObject var handTracker: HandTrackingService
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Noor Control")
                .font(.headline)
                .padding(.top, 8)
            
            Divider()
            
            Button("Show Debug Panel") {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "debug-window")
            }
            .keyboardShortcut("d", modifiers: .command)
            
            Button("Start Calibration") {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "calibration-window")
            }
            .keyboardShortcut("c", modifiers: .command)
            
            Divider()
            
            VStack(alignment: .leading) {
                Text("Status: \(handTracker.fps > 0 ? "Running" : "Idle")")
                    .font(.caption)
                Text("FPS: \(handTracker.fps, specifier: "%.1f")")
                    .font(.caption)
            }
            
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .padding(.bottom, 8)

        }
        .padding(.horizontal)
        .frame(width: 250)
    }
}
