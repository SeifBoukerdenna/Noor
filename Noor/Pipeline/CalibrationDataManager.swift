import Foundation
import AppKit

class CalibrationDataManager {
    
    private let baseURL: URL
    private var sessionURL: URL?
    
    init() {
        // ~/Library/Application Support/Noor/calibration_sessions/
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        self.baseURL = appSupport.appendingPathComponent("Noor/calibration_sessions")
        
        try? FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
    }
    
    func startSession(_ session: CalibrationSession) throws {
        let sessionDir = baseURL.appendingPathComponent(session.sessionID)
        try FileManager.default.createDirectory(at: sessionDir, withIntermediateDirectories: true)
        self.sessionURL = sessionDir
        
        // Save session.json
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(session)
        try data.write(to: sessionDir.appendingPathComponent("session.json"))
    }
    
    func saveTarget(_ target: CalibrationTarget) throws {
        guard let sessionURL = sessionURL else { throw CalibrationError.noActiveSession }
        
        let targetDir = sessionURL.appendingPathComponent("target_\(String(format: "%03d", target.targetID))")
        try FileManager.default.createDirectory(at: targetDir, withIntermediateDirectories: true)
        
        // Save target.json
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(target)
        try data.write(to: targetDir.appendingPathComponent("target.json"))
    }
    
    func saveFrame(
        targetID: Int,
        frameIndex: Int,
        leftEye: NSImage,
        rightEye: NSImage,
        metadata: FrameMetadata
    ) throws {
        guard let sessionURL = sessionURL else { throw CalibrationError.noActiveSession }
        
        let targetDir = sessionURL.appendingPathComponent("target_\(String(format: "%03d", targetID))")
        let framesDir = targetDir.appendingPathComponent("frames")
        try FileManager.default.createDirectory(at: framesDir, withIntermediateDirectories: true)
        
        let prefix = "f\(String(format: "%02d", frameIndex))"
        
        // Save left eye
        if let leftData = leftEye.jpegData(quality: 0.95) {
            try leftData.write(to: framesDir.appendingPathComponent("\(prefix)_left.jpg"))
        }
        
        // Save right eye
        if let rightData = rightEye.jpegData(quality: 0.95) {
            try rightData.write(to: framesDir.appendingPathComponent("\(prefix)_right.jpg"))
        }
        
        // Save metadata
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let metaData = try encoder.encode(metadata)
        try metaData.write(to: framesDir.appendingPathComponent("\(prefix)_meta.json"))
    }
    
    func getSessionURL() -> URL? {
        return sessionURL
    }
}

extension NSImage {
    func jpegData(quality: CGFloat = 0.9) -> Data? {
        guard let cgImage = self.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        
        let bitmap = NSBitmapImageRep(cgImage: cgImage)
        return bitmap.representation(using: .jpeg, properties: [.compressionFactor: quality])
    }
}

enum CalibrationError: Error {
    case noActiveSession
    case faceLandmarksNotFound
    case eyeCropFailed
    case invalidFrameData
}
