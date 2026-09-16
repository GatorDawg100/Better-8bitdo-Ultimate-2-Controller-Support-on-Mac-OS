import Foundation
import CoreGraphics
import simd

/// Complete instantaneous hardware state snapshot of the 8BitDo Ultimate 2 Wireless Controller.
public struct EightBitDoState: Equatable, Sendable {
    // Thumbsticks (-1.0 to 1.0, Y-up positive)
    public var leftStick: CGPoint
    public var rightStick: CGPoint
    
    // Analog Triggers (0.0 to 1.0)
    public var leftTrigger: Float
    public var rightTrigger: Float
    
    // Face Buttons
    public var buttonA: Bool
    public var buttonB: Bool
    public var buttonX: Bool
    public var buttonY: Bool
    
    // Bumpers
    public var buttonLB: Bool
    public var buttonRB: Bool
    
    // Stick Clicks
    public var buttonL3: Bool
    public var buttonR3: Bool
    
    // System / Navigation Buttons
    public var buttonSelect: Bool
    public var buttonStart: Bool
    public var buttonHome: Bool
    
    // D-Pad Directional
    public var dpadUp: Bool
    public var dpadDown: Bool
    public var dpadLeft: Bool
    public var dpadRight: Bool
    
    // Back Paddles
    public var paddleM1: Bool
    public var paddleM2: Bool
    
    // 6-Axis Motion & Telemetry
    public var acceleration: SIMD3<Float>       // in g units (1.0 = earth gravity)
    public var angularVelocityDeg: SIMD3<Float> // deg/s
    public var angularVelocityRad: SIMD3<Float> // rad/s
    public var gravity: SIMD3<Float>            // Normalized gravity vector
    public var pitch: Float                     // Estimated attitude pitch in degrees
    public var roll: Float                      // Estimated attitude roll in degrees
    public var yaw: Float                       // Estimated attitude yaw in degrees
    
    // Metadata
    public var timestamp: TimeInterval
    public var reportIndex: UInt64
    
    public init(
        leftStick: CGPoint = .zero,
        rightStick: CGPoint = .zero,
        leftTrigger: Float = 0,
        rightTrigger: Float = 0,
        buttonA: Bool = false,
        buttonB: Bool = false,
        buttonX: Bool = false,
        buttonY: Bool = false,
        buttonLB: Bool = false,
        buttonRB: Bool = false,
        buttonL3: Bool = false,
        buttonR3: Bool = false,
        buttonSelect: Bool = false,
        buttonStart: Bool = false,
        buttonHome: Bool = false,
        dpadUp: Bool = false,
        dpadDown: Bool = false,
        dpadLeft: Bool = false,
        dpadRight: Bool = false,
        paddleM1: Bool = false,
        paddleM2: Bool = false,
        acceleration: SIMD3<Float> = .zero,
        angularVelocityDeg: SIMD3<Float> = .zero,
        angularVelocityRad: SIMD3<Float> = .zero,
        gravity: SIMD3<Float> = SIMD3<Float>(0, 0, -1),
        pitch: Float = 0,
        roll: Float = 0,
        yaw: Float = 0,
        timestamp: TimeInterval = 0,
        reportIndex: UInt64 = 0
    ) {
        self.leftStick = leftStick
        self.rightStick = rightStick
        self.leftTrigger = leftTrigger
        self.rightTrigger = rightTrigger
        self.buttonA = buttonA
        self.buttonB = buttonB
        self.buttonX = buttonX
        self.buttonY = buttonY
        self.buttonLB = buttonLB
        self.buttonRB = buttonRB
        self.buttonL3 = buttonL3
        self.buttonR3 = buttonR3
        self.buttonSelect = buttonSelect
        self.buttonStart = buttonStart
        self.buttonHome = buttonHome
        self.dpadUp = dpadUp
        self.dpadDown = dpadDown
        self.dpadLeft = dpadLeft
        self.dpadRight = dpadRight
        self.paddleM1 = paddleM1
        self.paddleM2 = paddleM2
        self.acceleration = acceleration
        self.angularVelocityDeg = angularVelocityDeg
        self.angularVelocityRad = angularVelocityRad
        self.gravity = gravity
        self.pitch = pitch
        self.roll = roll
        self.yaw = yaw
        self.timestamp = timestamp
        self.reportIndex = reportIndex
    }
    
    /// Query whether a specific EightBitDoButton is currently active
    public func isPressed(_ button: EightBitDoButton) -> Bool {
        switch button {
        case .a: return buttonA
        case .b: return buttonB
        case .x: return buttonX
        case .y: return buttonY
        case .lb: return buttonLB
        case .rb: return buttonRB
        case .lt: return leftTrigger > 0.3
        case .rt: return rightTrigger > 0.3
        case .l3: return buttonL3
        case .r3: return buttonR3
        case .select: return buttonSelect
        case .start: return buttonStart
        case .home: return buttonHome
        case .dpadUp: return dpadUp
        case .dpadDown: return dpadDown
        case .dpadLeft: return dpadLeft
        case .dpadRight: return dpadRight
        case .paddleM1: return paddleM1
        case .paddleM2: return paddleM2
        }
    }
}
