import Testing
import Foundation
@testable import ControllerTester
import EightBitDoKit
import DualSenseEmulationKit

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
        bytes[6] = 0x01 // Button A (bit 0)
        bytes[7] = (1 << 5) // L3 (bit 5)
        bytes[8] = 255  // LT Max
        bytes[9] = 128  // RT 50%
        bytes[10] = 0x03 // Paddles M1 (bit 0) and M2 (bit 1)
        
        let data = Data(bytes)
        let state = decoder.decode(data: data, timestamp: 100.0)
        
        #expect(state != nil)
        guard let s = state else { return }
        
        #expect(s.buttonA == true)
        #expect(s.buttonB == false)
        #expect(s.buttonL3 == true)
        #expect(s.dpadUp == true)
        #expect(s.paddleM1 == true)
        #expect(s.paddleM2 == true)
        #expect(s.leftTrigger == 1.0)
        #expect(abs(s.rightTrigger - 0.502) < 0.01)
        #expect(s.leftStick.x > 0.95)
        #expect(s.leftStick.y > 0.95)
    }
    
    // MARK: - DualSenseEmulationKit Tests
    
    @Test("DualSenseReportPacker produces valid 64-byte DualSense report with Touchpad mapping")
    func testDualSenseReportPacker() {
        var packer = DualSenseReportPacker()
        var ebState = EightBitDoState()
        
        ebState.buttonA = true
        ebState.paddleM1 = true // Should map to Touchpad Click in standard profile!
        ebState.paddleM2 = true // Should map to L3 in standard profile!
        ebState.leftTrigger = 0.8
        ebState.rightTrigger = 1.0
        
        let profile = RemappingProfile.standard
        let report = packer.pack(state: ebState, profile: profile)
        
        #expect(report.count == 64)
        #expect(report[0] == 0x01) // Report ID 1
        
        // Face button byte 8: Cross is bit 5 (0x20)
        let b8 = report[8]
        #expect((b8 & 0x20) != 0)
        
        // Touchpad click byte 10: Bit 1 (0x02)
        let b10 = report[10]
        #expect((b10 & 0x02) != 0) // Touchpad click mapped from M1!
        
        // Analog triggers: Byte 5 (L2) and Byte 6 (R2)
        #expect(report[5] > 180)
        #expect(report[6] == 255)
    }
    
    @Test("RemappingProfile JSON serialization and default presets")
    func testRemappingProfileSerialization() throws {
        let profile = RemappingProfile.standard
        #expect(profile.buttonMap[.paddleM1] == .touchpad)
        #expect(profile.buttonMap[.paddleM2] == .l3)
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(profile)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(RemappingProfile.self, from: data)
        
        #expect(decoded.id == profile.id)
        #expect(decoded.name == profile.name)
        #expect(decoded.buttonMap[.paddleM1] == .touchpad)
        #expect(decoded.buttonMap[.paddleM2] == .l3)
        #expect(decoded.rumbleEnabled == profile.rumbleEnabled)
        #expect(decoded.gyroEnabled == profile.gyroEnabled)
    }
}
