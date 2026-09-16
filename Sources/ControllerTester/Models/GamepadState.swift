import Foundation
import GameController
import SwiftUI

/// Represents the instantaneous state of a button input
public struct ButtonInputState: Equatable, Sendable {
    public var isPressed: Bool = false
    public var value: Float = 0.0
    public var pressCount: Int = 0
    public var lastPressedAt: Date? = nil
    public var lastPressDurationMs: Double = 0.0
    
    public mutating func update(pressed: Bool, value: Float) {
        let now = Date()
        if pressed && !self.isPressed {
            pressCount += 1
            lastPressedAt = now
        } else if !pressed && self.isPressed {
            if let start = lastPressedAt {
                lastPressDurationMs = now.timeIntervalSince(start) * 1000.0
            }
        }
        self.isPressed = pressed
        self.value = value
    }
    
    public mutating func resetCount() {
        pressCount = 0
        lastPressDurationMs = 0.0
        lastPressedAt = nil
    }
}

/// Represents the position and polar coordinates of an analog thumbstick
public struct ThumbstickState: Equatable, Sendable {
    public var x: Float = 0.0
    public var y: Float = 0.0
    
    public var magnitude: Float {
        sqrt(x * x + y * y)
    }
    
    public var angleDegrees: Double {
        let rad = atan2(Double(y), Double(x))
        var deg = rad * 180.0 / .pi
        if deg < 0 { deg += 360.0 }
        return deg
    }
}

/// Represents the physical or simulated motion attitude of the controller
public struct ControllerMotionState: Equatable, Sendable {
    public var hasMotion: Bool = false
    public var pitch: Double = 0.0
    public var roll: Double = 0.0
    public var yaw: Double = 0.0
    
    public var rotationRateX: Double = 0.0
    public var rotationRateY: Double = 0.0
    public var rotationRateZ: Double = 0.0
    
    public var gravityX: Double = 0.0
    public var gravityY: Double = 0.0
    public var gravityZ: Double = -1.0
    
    public var userAccelX: Double = 0.0
    public var userAccelY: Double = 0.0
    public var userAccelZ: Double = 0.0
}

/// Observable state representing the complete live state of the controller inputs
@MainActor
public final class GamepadState: ObservableObject {
    // Controller Identification
    @Published public var id: String = "simulated"
    @Published public var vendorName: String = "No Controller Connected"
    @Published public var productCategory: String = "None"
    @Published public var playerIndex: Int = 1
    @Published public var isConnected: Bool = false
    @Published public var isSimulated: Bool = true
    @Published public var batteryLevel: Float? = nil
    @Published public var batteryState: GCDeviceBattery.State? = nil
    @Published public var hasHaptics: Bool = false
    
    // Face buttons
    @Published public var buttonA: ButtonInputState = ButtonInputState()
    @Published public var buttonB: ButtonInputState = ButtonInputState()
    @Published public var buttonX: ButtonInputState = ButtonInputState()
    @Published public var buttonY: ButtonInputState = ButtonInputState()
    
    // Shoulders
    @Published public var leftShoulder: ButtonInputState = ButtonInputState()
    @Published public var rightShoulder: ButtonInputState = ButtonInputState()
    
    // Triggers
    @Published public var leftTrigger: ButtonInputState = ButtonInputState()
    @Published public var rightTrigger: ButtonInputState = ButtonInputState()
    
    // D-Pad
    @Published public var dpadUp: ButtonInputState = ButtonInputState()
    @Published public var dpadDown: ButtonInputState = ButtonInputState()
    @Published public var dpadLeft: ButtonInputState = ButtonInputState()
    @Published public var dpadRight: ButtonInputState = ButtonInputState()
    @Published public var dpadX: Float = 0.0
    @Published public var dpadY: Float = 0.0
    
    // Thumbsticks
    @Published public var leftStick: ThumbstickState = ThumbstickState()
    @Published public var rightStick: ThumbstickState = ThumbstickState()
    @Published public var leftStickButton: ButtonInputState = ButtonInputState() // L3
    @Published public var rightStickButton: ButtonInputState = ButtonInputState() // R3
    
    // System buttons
    @Published public var buttonMenu: ButtonInputState = ButtonInputState()      // Start / Menu
    @Published public var buttonOptions: ButtonInputState = ButtonInputState()   // Select / Share / Options
    @Published public var buttonHome: ButtonInputState = ButtonInputState()      // Guide / PS / Xbox
    
    // Back Paddles
    @Published public var paddle1: ButtonInputState = ButtonInputState()
    @Published public var paddle2: ButtonInputState = ButtonInputState()
    @Published public var paddle3: ButtonInputState = ButtonInputState()
    @Published public var paddle4: ButtonInputState = ButtonInputState()
    
    // Dynamic Extra Buttons (e.g. 8BitDo M1, M2, L4, R4)
    @Published public var dynamicButtons: [String: ButtonInputState] = [:]
    @Published public var dynamicButtonMetadata: [String: (name: String, symbol: String)] = [:]
    @Published public var isHidPCMode: Bool = false
    @Published public var hardwareAdvisory: String? = nil
    
    // Motion
    @Published public var motion: ControllerMotionState = ControllerMotionState()
    
    // Polling rate and telemetry
    @Published public var pollingRateHz: Double = 0.0
    @Published public var totalEventsCount: Int = 0
    
    // Sliding window of event timestamps for polling rate calculation
    private var eventTimestamps: [TimeInterval] = []
    private var lastRateCalculationTime: TimeInterval = 0
    
    public init() {}
    
    /// Records a polling event and updates polling frequency (Hz)
    public func recordEvent() {
        totalEventsCount += 1
        let now = ProcessInfo.processInfo.systemUptime
        eventTimestamps.append(now)
        
        // Remove timestamps older than 1.0 second
        let cutoff = now - 1.0
        eventTimestamps.removeAll { $0 < cutoff }
        
        // Update polling rate calculation at most every 0.1s
        if now - lastRateCalculationTime >= 0.1 {
            pollingRateHz = Double(eventTimestamps.count)
            lastRateCalculationTime = now
        }
    }
    
    /// Reset all button hit counters
    public func resetCounters() {
        buttonA.resetCount()
        buttonB.resetCount()
        buttonX.resetCount()
        buttonY.resetCount()
        leftShoulder.resetCount()
        rightShoulder.resetCount()
        leftTrigger.resetCount()
        rightTrigger.resetCount()
        dpadUp.resetCount()
        dpadDown.resetCount()
        dpadLeft.resetCount()
        dpadRight.resetCount()
        leftStickButton.resetCount()
        rightStickButton.resetCount()
        buttonMenu.resetCount()
        buttonOptions.resetCount()
        buttonHome.resetCount()
        paddle1.resetCount()
        paddle2.resetCount()
        paddle3.resetCount()
        paddle4.resetCount()
        for key in dynamicButtons.keys {
            dynamicButtons[key]?.resetCount()
        }
        totalEventsCount = 0
    }
    
    /// Updates or registers a dynamically detected button (such as 8BitDo M1, M2, L4, R4)
    public func updateDynamicButton(key: String, name: String, symbol: String?, pressed: Bool, value: Float) {
        var btn = dynamicButtons[key] ?? ButtonInputState()
        btn.update(pressed: pressed, value: value)
        dynamicButtons[key] = btn
        if dynamicButtonMetadata[key] == nil {
            dynamicButtonMetadata[key] = (name: name, symbol: symbol ?? "circle.fill")
        }
    }
    
    /// Reset stick and trigger values to neutral
    public func resetToNeutral() {
        leftStick = ThumbstickState()
        rightStick = ThumbstickState()
        dpadX = 0.0
        dpadY = 0.0
        leftTrigger.update(pressed: false, value: 0.0)
        rightTrigger.update(pressed: false, value: 0.0)
    }
}
