import Foundation

enum HandChirality { case left, right }
enum StaticGesture: String { case fist = "Fist", open = "Open", unknown = "---" }
enum DynamicGesture: String { case movingUp = "Up", movingDown = "Down", stationary = "---" }

struct HandState {
    let chirality: HandChirality
    let staticGesture: StaticGesture
    let dynamicGesture: DynamicGesture
}
