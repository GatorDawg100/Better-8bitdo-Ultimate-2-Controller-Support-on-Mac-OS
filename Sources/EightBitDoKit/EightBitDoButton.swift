import Foundation

/// Individual physical inputs available on the 8BitDo Ultimate 2 Wireless Controller.
public enum EightBitDoButton: String, CaseIterable, Codable, Sendable {
    // Face Buttons
    case a = "A"
    case b = "B"
    case x = "X"
    case y = "Y"
    
    // Bumpers & Triggers (Digital)
    case lb = "LB"
    case rb = "RB"
    case lt = "LT (Digital)"
    case rt = "RT (Digital)"
    case l4 = "L4"
    case r4 = "R4"
    
    // Stick Clicks
    case l3 = "L3"
    case r3 = "R3"
    
    // Navigation / Menu
    case select = "Select"
    case start = "Start"
    case home = "Home"
    
    // D-Pad
    case dpadUp = "D-Pad Up"
    case dpadDown = "D-Pad Down"
    case dpadLeft = "D-Pad Left"
    case dpadRight = "D-Pad Right"
    
    // Back Paddles
    case paddleM1 = "Paddle M1"
    case paddleM2 = "Paddle M2"
    
    public var isPaddle: Bool {
        self == .paddleM1 || self == .paddleM2
    }
}
