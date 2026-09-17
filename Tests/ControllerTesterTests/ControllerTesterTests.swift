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
}

