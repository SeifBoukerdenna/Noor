import Foundation
import SwiftUI

class WindowManager: ObservableObject {
    static let shared = WindowManager()
    
    @Published var isDebugWindowOpen = false
    @Published var isCalibrationWindowOpen = false
    
    private init() {}
}
