import Testing
import Foundation
@testable import ControllerTester

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
}
