import SwiftUI
import AVFoundation

struct CameraPreviewView: NSViewRepresentable {
    
    let previewLayer: AVCaptureVideoPreviewLayer
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.layer = previewLayer
        view.layer?.cornerRadius = 10
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
}
