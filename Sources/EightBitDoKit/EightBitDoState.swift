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
    public var buttonL4: Bool
    public var buttonR4: Bool
    
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
        buttonL4: Bool = false,
        buttonR4: Bool = false,
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
        self.buttonL4 = buttonL4
        self.buttonR4 = buttonR4
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
    public func isPressed(_ button: EightBitDoButton, triggerThreshold: Float = 0.3) -> Bool {
        switch button {
        case .a: return buttonA
        case .b: return buttonB
        case .x: return buttonX
        case .y: return buttonY
        case .lb: return buttonLB
        case .rb: return buttonRB
        case .lt: return leftTrigger > triggerThreshold
        case .rt: return rightTrigger > triggerThreshold
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
        case .l4: return buttonL4
        case .r4: return buttonR4
        }
    }
    
    /// Array of all buttons currently in an active / pressed state
    public var pressedButtons: [EightBitDoButton] {
        EightBitDoButton.allCases.filter { isPressed($0) }
    }
    
    /// Returns true if any physical button, bumper, trigger, paddle, or D-pad direction is pressed
    public var isAnyButtonPressed: Bool {
        buttonA || buttonB || buttonX || buttonY ||
        buttonLB || buttonRB || buttonL4 || buttonR4 ||
        buttonL3 || buttonR3 || buttonSelect || buttonStart || buttonHome ||
        dpadUp || dpadDown || dpadLeft || dpadRight ||
        paddleM1 || paddleM2 || leftTrigger > 0.3 || rightTrigger > 0.3
    }
    
    // MARK: - Thumbstick Polar & Deadzone Calculations
    
    /// Radial magnitude of the left stick (0.0 at center, up to ~1.0 at outer rim)
    public var leftStickMagnitude: Float {
        Float(hypot(leftStick.x, leftStick.y))
    }
    
    /// Radial magnitude of the right stick (0.0 at center, up to ~1.0 at outer rim)
    public var rightStickMagnitude: Float {
        Float(hypot(rightStick.x, rightStick.y))
    }
    
    /// Angle of the left stick in degrees (0° = East/Right, 90° = North/Up, 180° = West/Left, 270° = South/Down)
    public var leftStickAngleDegrees: Float {
        let dx = Float(leftStick.x)
        let dy = Float(leftStick.y)
        guard hypot(dx, dy) >= 0.001 else { return 0.0 }
        var angle = atan2(dy, dx) * (180.0 / .pi)
        if angle < 0 { angle += 360.0 }
        return angle
    }
    
    /// Angle of the right stick in degrees (0° = East/Right, 90° = North/Up, 180° = West/Left, 270° = South/Down)
    public var rightStickAngleDegrees: Float {
        let dx = Float(rightStick.x)
        let dy = Float(rightStick.y)
        guard hypot(dx, dy) >= 0.001 else { return 0.0 }
        var angle = atan2(dy, dx) * (180.0 / .pi)
        if angle < 0 { angle += 360.0 }
        return angle
    }
    
    /// Angle of the left stick in radians (0 to 2π)
    public var leftStickAngleRadians: Float {
        let dx = Float(leftStick.x)
        let dy = Float(leftStick.y)
        guard hypot(dx, dy) >= 0.001 else { return 0.0 }
        var angle = atan2(dy, dx)
        if angle < 0 { angle += 2.0 * .pi }
        return angle
    }
    
    /// Angle of the right stick in radians (0 to 2π)
    public var rightStickAngleRadians: Float {
        let dx = Float(rightStick.x)
        let dy = Float(rightStick.y)
        guard hypot(dx, dy) >= 0.001 else { return 0.0 }
        var angle = atan2(dy, dx)
        if angle < 0 { angle += 2.0 * .pi }
        return angle
    }
    
    /// Returns the left stick vector with a radial deadzone applied.
    /// Deflections below `deadzone` return `CGPoint.zero`. Deflections above are smoothly remapped from 0.0 to 1.0.
    public func leftStickWithDeadzone(_ deadzone: Float = 0.08) -> CGPoint {
        Self.applyRadialDeadzone(stick: leftStick, deadzone: deadzone)
    }
    
    /// Returns the right stick vector with a radial deadzone applied.
    /// Deflections below `deadzone` return `CGPoint.zero`. Deflections above are smoothly remapped from 0.0 to 1.0.
    public func rightStickWithDeadzone(_ deadzone: Float = 0.08) -> CGPoint {
        Self.applyRadialDeadzone(stick: rightStick, deadzone: deadzone)
    }
    
    private static func applyRadialDeadzone(stick: CGPoint, deadzone: Float) -> CGPoint {
        let dx = Float(stick.x)
        let dy = Float(stick.y)
        let mag = hypot(dx, dy)
        guard mag > deadzone else { return .zero }
        let normalizedMag = (mag - deadzone) / (1.0 - deadzone)
        let clampedMag = min(1.0, max(0.0, normalizedMag))
        let factor = CGFloat(clampedMag / mag)
        return CGPoint(x: stick.x * factor, y: stick.y * factor)
    }
    
    // MARK: - Motion Diagnostics
    
    /// Total acceleration vector magnitude in g
    public var totalAcceleration: Float {
        simd_length(acceleration)
    }
    
    /// Total angular rate magnitude in deg/s
    public var totalAngularVelocityDeg: Float {
        simd_length(angularVelocityDeg)
    }
    
    /// Whether the controller is resting stationary on a surface
    public var isResting: Bool {
        abs(totalAcceleration - 1.0) < 0.1 && totalAngularVelocityDeg < 2.0
    }
}

extension EightBitDoState: CustomStringConvertible {
    public var description: String {
        "EightBitDoState(LX: \(String(format: "%.2f", leftStick.x)), LY: \(String(format: "%.2f", leftStick.y)), LT: \(String(format: "%.2f", leftTrigger)), RT: \(String(format: "%.2f", rightTrigger)), Pitch: \(String(format: "%.1f°", pitch)), Roll: \(String(format: "%.1f°", roll)), Yaw: \(String(format: "%.1f°", yaw)))"
    }
}
