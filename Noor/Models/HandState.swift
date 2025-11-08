import Foundation

enum HandChirality { case left, right }
enum StaticGesture: String { case fist = "Fist", open = "Open", pinch = "Pinch", unknown = "---" }
enum DynamicGesture: String { case movingUp = "Up", movingDown = "Down", stationary = "---" }
enum PalmOrientation: String { case facingScreen = "→ Screen", facingAway = "← Away", neutral = "---" }

struct HandState {
    let chirality: HandChirality
    let staticGesture: StaticGesture
    let dynamicGesture: DynamicGesture
    let palmOrientation: PalmOrientation
}
