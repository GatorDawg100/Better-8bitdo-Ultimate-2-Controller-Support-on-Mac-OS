import Testing
import Foundation
@testable import ControllerTester
import EightBitDoKit

@Suite("Controller Tester Core Tests")
struct ControllerTesterTests {
    
    @Test("Thumbstick polar coordinate and magnitude calculations")
    func testThumbstickCalculations() {
        var stick = ThumbstickState(x: 0, y: 0)
        #expect(stick.magnitude == 0)
        #expect(stick.angleDegrees == 0)
        
        // Right (X: 1, Y: 0) -> Angle 0°
        stick = ThumbstickState(x: 1, y: 0)
        #expect(stick.magnitude == 1.0)
        #expect(stick.angleDegrees == 0)
        
        // Up (X: 0, Y: 1) -> Angle 90°
        stick = ThumbstickState(x: 0, y: 1)
        #expect(stick.magnitude == 1.0)
        #expect(abs(stick.angleDegrees - 90.0) < 0.001)
        
        // Left (X: -1, Y: 0) -> Angle 180°
        stick = ThumbstickState(x: -1, y: 0)
        #expect(stick.magnitude == 1.0)
        #expect(abs(stick.angleDegrees - 180.0) < 0.001)
        
        // Down (X: 0, Y: -1) -> Angle 270°
        stick = ThumbstickState(x: 0, y: -1)
        #expect(stick.magnitude == 1.0)
        #expect(abs(stick.angleDegrees - 270.0) < 0.001)
    }
    
    @Test("ButtonInputState tracks actuations and hold durations")
    func testButtonActuationTracking() {
        var btn = ButtonInputState()
        #expect(btn.pressCount == 0)
        #expect(!btn.isPressed)
        
        // Press
        btn.update(pressed: true, value: 1.0)
        #expect(btn.pressCount == 1)
        #expect(btn.isPressed)
        #expect(btn.value == 1.0)
        
        // Release
        btn.update(pressed: false, value: 0.0)
        #expect(btn.pressCount == 1)
        #expect(!btn.isPressed)
        #expect(btn.value == 0.0)
        
        // Press again
        btn.update(pressed: true, value: 0.8)
        #expect(btn.pressCount == 2)
        #expect(btn.isPressed)
        
        // Reset
        btn.resetCount()
        #expect(btn.pressCount == 0)
    }
    
    @MainActor
    @Test("Drift diagnostic manager tracks resting offset and circularity bins")
    func testDriftDiagnostics() {
        let drift = DriftDiagnosticManager()
        drift.deadzoneThreshold = 0.05
        
        // Neutral position
        drift.update(leftX: 0.02, leftY: 0.01, rightX: 0.0, rightY: 0.0)
        #expect(drift.leftRestingOffset < 0.05)
        #expect(drift.leftMaxRestingDrift > 0)
        
        // Deflected position
        drift.update(leftX: 0.10, leftY: 0.0, rightX: 0.0, rightY: 0.0)
        #expect(drift.leftRestingOffset == 0.10)
        #expect(drift.leftMaxRestingDrift == 0.10)
        
        // Circularity test
        drift.isCircularityTestActive = true
        drift.activeTestStick = .left
        drift.update(leftX: 1.0, leftY: 0.0, rightX: 0.0, rightY: 0.0)
        
        let completion = drift.completionPercentage(for: .left)
        #expect(completion > 0)
    }
    
    @MainActor
    @Test("InputLogManager limits entries and filters by category and search text")
    func testInputLogFiltering() {
        let log = InputLogManager()
        log.log(element: "Button A", category: .button, valueDescription: "Pressed (1.00)", isPressed: true)
        log.log(element: "Left Trigger", category: .trigger, valueDescription: "Value: 0.65", isPressed: true)
        log.log(element: "Left Stick", category: .thumbstick, valueDescription: "X: 0.50, Y: -0.20")
        
        #expect(log.entries.count == 3)
        
        // Filter by button
        log.selectedCategory = .button
        #expect(log.filteredEntries.count == 1)
        #expect(log.filteredEntries.first?.element == "Button A")
        
        // Search text
        log.selectedCategory = .all
        log.searchText = "Trigger"
        #expect(log.filteredEntries.count == 1)
        #expect(log.filteredEntries.first?.element == "Left Trigger")
        
        log.clear()
        #expect(log.entries.isEmpty)
    }
    
    // MARK: - EightBitDoKit Tests
    
    @Test("EightBitDoPacketDecoder decodes sticks, triggers, face buttons, and back paddles")
    func testEightBitDoPacketDecoder() {
        let decoder = EightBitDoPacketDecoder()
        
        var bytes = [UInt8](repeating: 0, count: 34)
        bytes[0] = 0x01 // Report ID 1
        bytes[1] = 0x00 // D-Pad Up
        bytes[2] = 255  // LX Max Right
        bytes[3] = 0    // LY Max Up (inverted)
        bytes[4] = 128  // RX Center
        bytes[5] = 128  // RY Center
        bytes[6] = 255  // LT Max
        bytes[7] = 128  // RT 50%
        bytes[8] = (1 << 0) | (1 << 5) | (1 << 2) // Button A (bit 0), M1 (bit 5), M2 (bit 2)
        bytes[9] = (1 << 5) | (1 << 4) // L3 (bit 5), Home (bit 4)
        bytes[10] = (1 << 0) | (1 << 1) // L4 (bit 0), R4 (bit 1)
        
        let data = Data(bytes)
        let state = decoder.decode(data: data, timestamp: 100.0)
        
        #expect(state != nil)
        guard let s = state else { return }
        
        #expect(s.buttonA == true)
        #expect(s.buttonB == false)
        #expect(s.buttonL3 == true)
        #expect(s.buttonHome == true)
        #expect(s.isPressed(.home) == true)
        #expect(s.dpadUp == true)
        #expect(s.paddleM1 == true)
        #expect(s.paddleM2 == true)
        #expect(s.buttonL4 == true)
        #expect(s.buttonR4 == true)
        #expect(s.isPressed(.l4) == true)
        #expect(s.isPressed(.r4) == true)
        #expect(s.leftTrigger == 1.0)
        #expect(abs(s.rightTrigger - 0.502) < 0.01)
        #expect(s.leftStick.x > 0.95)
        #expect(s.leftStick.y > 0.95)
    }
    
    @Test("Left Trigger digital bit does not trigger Home button")
    func testLeftTriggerDoesNotTriggerHome() {
        let decoder = EightBitDoPacketDecoder()
        var bytes = [UInt8](repeating: 0, count: 34)
        bytes[0] = 0x01
        bytes[6] = 255      // Analog LT full pull (Byte 6)
        bytes[9] = (1 << 0) // Digital LT bit in byte 9
        
        let state = decoder.decode(data: Data(bytes), timestamp: 1.0)
        #expect(state != nil)
        #expect(state?.buttonHome == false)
        #expect(state?.leftTrigger == 1.0)
    }
    
    @Test("EightBitDoPacketDecoder decodes 6-axis IMU accelerometer and gyroscope")
    func testIMUDecoding() {
        let decoder = EightBitDoPacketDecoder()
        decoder.resetOrientation()
        
        var bytes = [UInt8](repeating: 0, count: 34)
        bytes[0] = 0x01 // Report ID 1
        
        // Flat on table facing up: az ≈ +4096 (+1.0g), ax = 0, ay = 0
        let azLE: UInt16 = 4096
        bytes[19] = UInt8(azLE & 0xFF)
        bytes[20] = UInt8((azLE >> 8) & 0xFF)
        
        // Initial state decode
        let s1 = decoder.decode(data: Data(bytes), timestamp: 1.0)
        #expect(s1 != nil)
        guard let state1 = s1 else { return }
        
        #expect(abs(state1.acceleration.z - 1.0) < 0.05)
        #expect(abs(state1.pitch) < 1.0)
        #expect(abs(state1.roll) < 1.0)
        
        // Tilt forward (nose down): ay goes positive -> roll goes positive (swapped axes)
        let ayLE: UInt16 = 2048 // ~ +0.5g
        bytes[17] = UInt8(ayLE & 0xFF)
        bytes[18] = UInt8((ayLE >> 8) & 0xFF)
        
        let s2 = decoder.decode(data: Data(bytes), timestamp: 1.05)
        #expect(s2 != nil)
        guard let state2 = s2 else { return }
        #expect(state2.roll > 0.0) // Roll is positive when tilted forward (swapped axes)
        
        // Tilt left: ax goes negative -> pitch goes positive
        let axLE: UInt16 = UInt16(bitPattern: -2048)
        bytes[15] = UInt8(axLE & 0xFF)
        bytes[16] = UInt8((axLE >> 8) & 0xFF)
        
        let s3 = decoder.decode(data: Data(bytes), timestamp: 1.10)
        #expect(s3 != nil)
        guard let state3 = s3 else { return }
        #expect(state3.pitch > 0.0) // Pitch is positive when tilted left
    }
    
    @Test("EightBitDoState ergonomics: polar angles, magnitudes, deadzones, and button lists")
    func testEightBitDoStateErgonomics() {
        var state = EightBitDoState()
        #expect(!state.isAnyButtonPressed)
        #expect(state.pressedButtons.isEmpty)
        #expect(state.leftStickMagnitude == 0.0)
        #expect(state.leftStickAngleDegrees == 0.0)
        
        // Right deflection (X: 1.0, Y: 0.0)
        state.leftStick = CGPoint(x: 1.0, y: 0.0)
        #expect(abs(state.leftStickMagnitude - 1.0) < 0.001)
        #expect(abs(state.leftStickAngleDegrees - 0.0) < 0.001)
        
        // Up deflection (X: 0.0, Y: 1.0)
        state.leftStick = CGPoint(x: 0.0, y: 1.0)
        #expect(abs(state.leftStickMagnitude - 1.0) < 0.001)
        #expect(abs(state.leftStickAngleDegrees - 90.0) < 0.001)
        
        // Left deflection (X: -1.0, Y: 0.0)
        state.leftStick = CGPoint(x: -1.0, y: 0.0)
        #expect(abs(state.leftStickAngleDegrees - 180.0) < 0.001)
        
        // Down deflection (X: 0.0, Y: -1.0)
        state.leftStick = CGPoint(x: 0.0, y: -1.0)
        #expect(abs(state.leftStickAngleDegrees - 270.0) < 0.001)
        
        // Radial Deadzone
        // Deflection of 0.05 within default 0.08 deadzone should clamp to .zero
        state.leftStick = CGPoint(x: 0.05, y: 0.0)
        let filteredWithin = state.leftStickWithDeadzone(0.08)
        #expect(filteredWithin == .zero)
        
        // Deflection above deadzone should smoothly scale
        state.leftStick = CGPoint(x: 0.54, y: 0.0)
        let filteredAbove = state.leftStickWithDeadzone(0.08)
        #expect(filteredAbove.x > 0.45 && filteredAbove.x < 0.55)
        #expect(filteredAbove.y == 0.0)
        
        // Buttons
        state.buttonA = true
        state.paddleM1 = true
        state.buttonL4 = true
        state.leftTrigger = 0.8
        #expect(state.isAnyButtonPressed)
        
        let pressed = state.pressedButtons
        #expect(pressed.contains(.a))
        #expect(pressed.contains(.paddleM1))
        #expect(pressed.contains(.l4))
        #expect(pressed.contains(.lt))
        #expect(!pressed.contains(.b))
        #expect(!pressed.contains(.paddleM2))
    }
    
    @Test("Stationary gyroscope zero-rate drift bias cancellation")
    func testStationaryGyroBiasCancellation() {
        let decoder = EightBitDoPacketDecoder(
            configuration: EightBitDoPacketDecoder.Configuration(
                autoZeroGyroBias: true,
                stationaryDurationRequired: 0.20
            )
        )
        decoder.resetOrientation()
        decoder.resetGyroBias()
        
        var bytes = [UInt8](repeating: 0, count: 34)
        bytes[0] = 0x01
        
        // Flat stationary resting: Az = +4096 (1.0g)
        let azLE: UInt16 = 4096
        bytes[19] = UInt8(azLE & 0xFF)
        bytes[20] = UInt8((azLE >> 8) & 0xFF)
        
        // Small persistent zero-rate yaw drift on Gz: ~0.61 deg/s (10 LSB)
        let gzLE: UInt16 = 10
        bytes[25] = UInt8(gzLE & 0xFF)
        bytes[26] = UInt8((gzLE >> 8) & 0xFF)
        
        let data = Data(bytes)
        
        // Initial sample
        var lastState = decoder.decode(data: data, timestamp: 1.0)
        #expect(lastState != nil)
        
        // Simulate resting on desk for 0.5 seconds at 50Hz (25 packets)
        for i in 1...25 {
            let t = 1.0 + Double(i) * 0.02
            lastState = decoder.decode(data: data, timestamp: t)
        }
        
        // Gyro bias should have begun converging towards 0.61 deg/s
        let bias = decoder.currentGyroBiasDeg
        #expect(bias.z > 0.1) // Bias was learned
        
        // Corrected angular velocity should be reduced compared to raw 0.61
        if let st = lastState {
            #expect(st.angularVelocityDeg.z < 0.61)
        }
    }
    
    @Test("Decoder Configuration axis inversion")
    func testDecoderConfigurationInversion() {
        var config = EightBitDoPacketDecoder.Configuration()
        config.invertPitch = true
        config.invertRoll = true
        config.invertYaw = true
        
        let decoder = EightBitDoPacketDecoder(configuration: config)
        decoder.resetOrientation(pitch: 10, roll: 20, yaw: 30)
        
        var bytes = [UInt8](repeating: 0, count: 34)
        bytes[0] = 0x01
        let azLE: UInt16 = 4096
        bytes[19] = UInt8(azLE & 0xFF)
        bytes[20] = UInt8((azLE >> 8) & 0xFF)
        
        let state = decoder.decode(data: Data(bytes), timestamp: 1.0)
        #expect(state != nil)
        #expect(decoder.configuration.invertPitch == true)
        #expect(decoder.configuration.invertRoll == true)
        #expect(decoder.configuration.invertYaw == true)
    }
    
    @Test("EightBitDoDevice AsyncStream connections yield current state immediately")
    func testDeviceAsyncStreams() async {
        let device = EightBitDoDevice()
        var receivedConnection = false
        for await isConn in device.connections {
            receivedConnection = true
            #expect(isConn == false)
            break
        }
        #expect(receivedConnection == true)
    }
}


