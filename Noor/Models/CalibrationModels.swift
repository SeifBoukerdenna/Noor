import Foundation
import AppKit
import CoreGraphics

// MARK: - Session Models

struct CalibrationSession: Codable {
    let sessionID: String
    let timestamp: Date
    let deviceModel: String
    let cameraResolution: CGSize
    let cameraFPS: Int
    let screenResolution: CGSize
    let screenScale: CGFloat
    let totalTargets: Int
    let distanceRanges: [String]
    
    init() {
        self.sessionID = "session_\(Self.dateFormatter.string(from: Date()))"
        self.timestamp = Date()
        
        var size: Int = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        self.deviceModel = String(cString: model)
        
        self.cameraResolution = CGSize(width: 1280, height: 720)
        self.cameraFPS = 60
        
        if let screen = NSScreen.main {
            self.screenResolution = screen.frame.size
            self.screenScale = screen.backingScaleFactor
        } else {
            self.screenResolution = CGSize(width: 1920, height: 1080)
            self.screenScale = 2.0
        }
        
        self.totalTargets = 10
        self.distanceRanges = ["near", "medium", "far"]
    }
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter
    }()
}

struct CalibrationTarget: Codable {
    let targetID: Int
    let screenX: CGFloat
    let screenY: CGFloat
    let normalizedX: CGFloat
    let normalizedY: CGFloat
    let region: String
    var capturedFrames: Int = 0
    var usableFrames: Int = 0
    var averageLidGap: CGFloat = 0
    var averageDistanceProxy: CGFloat = 0
}

struct FrameMetadata: Codable {
    let frameIndex: Int
    let timestamp: TimeInterval
    let screenX: CGFloat
    let screenY: CGFloat
    let normalizedX: CGFloat
    let normalizedY: CGFloat
    let lidGap: CGFloat
    let interPupilDistance: CGFloat
    let distanceProxy: CGFloat
    let poseFeatures: [CGFloat]
    let usable: Bool
    let blurScore: CGFloat
    let leftEyeROI: CGRect
    let rightEyeROI: CGRect
}

// MARK: - Target Generation

enum ScreenRegion: String {
    case corner, edge, center
}

struct TargetGenerator {
    static func generateTargets(screenSize: CGSize) -> [CalibrationTarget] {
        var targets: [CalibrationTarget] = []
        
        // Simple 10-point grid for testing
        let positions: [(CGFloat, CGFloat, String)] = [
            (0.1, 0.1, "corner"),   // Top-left
            (0.5, 0.1, "edge"),     // Top-center
            (0.9, 0.1, "corner"),   // Top-right
            (0.1, 0.5, "edge"),     // Middle-left
            (0.5, 0.5, "center"),   // Center
            (0.9, 0.5, "edge"),     // Middle-right
            (0.1, 0.9, "corner"),   // Bottom-left
            (0.5, 0.9, "edge"),     // Bottom-center
            (0.9, 0.9, "corner"),   // Bottom-right
            (0.3, 0.3, "center")    // Extra center-ish
        ]
        
        for (index, pos) in positions.enumerated() {
            let x = pos.0 * screenSize.width
            let y = pos.1 * screenSize.height
            
            targets.append(CalibrationTarget(
                targetID: index,
                screenX: x,
                screenY: y,
                normalizedX: pos.0,
                normalizedY: pos.1,
                region: pos.2
            ))
        }
        
        return targets
    }
}

// MARK: - CGRect Codable Extension

extension CGRect: Codable {
    enum CodingKeys: String, CodingKey {
        case x, y, width, height
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(origin.x, forKey: .x)
        try container.encode(origin.y, forKey: .y)
        try container.encode(size.width, forKey: .width)
        try container.encode(size.height, forKey: .height)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let x = try container.decode(CGFloat.self, forKey: .x)
        let y = try container.decode(CGFloat.self, forKey: .y)
        let width = try container.decode(CGFloat.self, forKey: .width)
        let height = try container.decode(CGFloat.self, forKey: .height)
        self.init(x: x, y: y, width: width, height: height)
    }
}

extension CGSize: Codable {
    enum CodingKeys: String, CodingKey {
        case width, height
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(width, forKey: .width)
        try container.encode(height, forKey: .height)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let width = try container.decode(CGFloat.self, forKey: .width)
        let height = try container.decode(CGFloat.self, forKey: .height)
        self.init(width: width, height: height)
    }
}
