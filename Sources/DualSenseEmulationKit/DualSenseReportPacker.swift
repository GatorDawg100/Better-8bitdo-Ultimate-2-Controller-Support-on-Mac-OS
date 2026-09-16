import Foundation
import CoreGraphics
import EightBitDoKit

/// Packs `EightBitDoState` into the standard 64-byte USB DualSense Input Report (Report ID 0x01)
/// applying remapping, deadzones, trigger adjustments, and motion sensor translation.
public struct DualSenseReportPacker: Sendable {
    private var sequenceNumber: UInt8 = 0
    
    public init() {}
    
    public mutating func pack(state: EightBitDoState, profile: RemappingProfile) -> Data {
        var report = [UInt8](repeating: 0, count: DualSenseConstants.inputReportLength)
        
        // Byte 0: Report ID
        report[0] = DualSenseConstants.inputReportID
        
        // 1. Process Thumbsticks
        var lx = Float(state.leftStick.x)
        var ly = Float(state.leftStick.y)
        var rx = Float(state.rightStick.x)
        var ry = Float(state.rightStick.y)
        
        lx = applyDeadzone(lx, deadzone: profile.leftStickDeadzone)
        ly = applyDeadzone(ly, deadzone: profile.leftStickDeadzone)
        rx = applyDeadzone(rx, deadzone: profile.rightStickDeadzone)
        ry = applyDeadzone(ry, deadzone: profile.rightStickDeadzone)
        
        // DualSense axes: 0..255 (128 center). Y-axis is inverted: 0 is UP, 255 is DOWN.
        report[1] = axisToUInt8(lx)
        report[2] = axisToUInt8(-ly)
        report[3] = axisToUInt8(rx)
        report[4] = axisToUInt8(-ry)
        
        // 2. Process Triggers
        var lt = state.leftTrigger
        var rt = state.rightTrigger
        
        if profile.hairTriggers {
            if lt > 0.08 { lt = 1.0 }
            if rt > 0.08 { rt = 1.0 }
        } else {
            lt = applyTriggerDeadzone(lt, deadzone: profile.triggerDeadzone)
            rt = applyTriggerDeadzone(rt, deadzone: profile.triggerDeadzone)
        }
        
        report[5] = UInt8(max(0, min(255, lt * 255.0)))
        report[6] = UInt8(max(0, min(255, rt * 255.0)))
        
        // Byte 7: Rolling sequence counter
        sequenceNumber = sequenceNumber &+ 1
        report[7] = sequenceNumber
        
        // 3. Resolve Active DualSense Target Buttons via Remapping Profile
        var activeTargets = Set<DualSenseButtonTarget>()
        
        for button in EightBitDoButton.allCases {
            if state.isPressed(button) {
                let target = profile.target(for: button)
                if target != .none {
                    activeTargets.insert(target)
                }
            }
        }
        
        // 4. Encode D-Pad Hat Switch
        let dUp = activeTargets.contains(.dpadUp) || state.dpadUp
        let dDown = activeTargets.contains(.dpadDown) || state.dpadDown
        let dLeft = activeTargets.contains(.dpadLeft) || state.dpadLeft
        let dRight = activeTargets.contains(.dpadRight) || state.dpadRight
        
        let hatValue: UInt8
        if dUp && dRight { hatValue = 1 }
        else if dDown && dRight { hatValue = 3 }
        else if dDown && dLeft { hatValue = 5 }
        else if dUp && dLeft { hatValue = 7 }
        else if dUp { hatValue = 0 }
        else if dRight { hatValue = 2 }
        else if dDown { hatValue = 4 }
        else if dLeft { hatValue = 6 }
        else { hatValue = 8 } // Centered / Neutral
        
        // Byte 8: Hat (bits 0..3) & Face Buttons (bits 4..7)
        var byte8: UInt8 = hatValue & 0x0F
        if activeTargets.contains(.square) { byte8 |= (1 << 4) }
        if activeTargets.contains(.cross) { byte8 |= (1 << 5) }
        if activeTargets.contains(.circle) { byte8 |= (1 << 6) }
        if activeTargets.contains(.triangle) { byte8 |= (1 << 7) }
        report[8] = byte8
        
        // Byte 9: Shoulder & Navigation Buttons
        var byte9: UInt8 = 0
        if activeTargets.contains(.l1) { byte9 |= (1 << 0) }
        if activeTargets.contains(.r1) { byte9 |= (1 << 1) }
        if activeTargets.contains(.l2) || lt > 0.4 { byte9 |= (1 << 2) }
        if activeTargets.contains(.r2) || rt > 0.4 { byte9 |= (1 << 3) }
        if activeTargets.contains(.create) { byte9 |= (1 << 4) }
        if activeTargets.contains(.options) { byte9 |= (1 << 5) }
        if activeTargets.contains(.l3) { byte9 |= (1 << 6) }
        if activeTargets.contains(.r3) { byte9 |= (1 << 7) }
        report[9] = byte9
        
        // Byte 10: PS, Touchpad Click, Mute
        var byte10: UInt8 = 0
        if activeTargets.contains(.ps) { byte10 |= (1 << 0) }
        if activeTargets.contains(.touchpad) { byte10 |= (1 << 1) }
        if activeTargets.contains(.mute) { byte10 |= (1 << 2) }
        report[10] = byte10
        
        // 5. 6-Axis Motion / IMU Telemetry (Bytes 16..27)
        if profile.gyroEnabled {
            var gx = state.angularVelocityDeg.x * profile.gyroSensitivity
            var gy = state.angularVelocityDeg.y * profile.gyroSensitivity
            let gz = state.angularVelocityDeg.z * profile.gyroSensitivity
            
            if profile.gyroInvertX { gx = -gx }
            if profile.gyroInvertY { gy = -gy }
            
            // DualSense gyro scale: ~16 LSB per deg/s
            let dsGx = Int16(clamping: Int(gx * 16.0))
            let dsGy = Int16(clamping: Int(gy * 16.0))
            let dsGz = Int16(clamping: Int(gz * 16.0))
            
            // DualSense accel scale: ~8192 LSB per 1.0g
            let dsAx = Int16(clamping: Int(state.acceleration.x * 8192.0))
            let dsAy = Int16(clamping: Int(state.acceleration.y * 8192.0))
            let dsAz = Int16(clamping: Int(state.acceleration.z * 8192.0))
            
            writeLE16(dsGx, into: &report, at: 16)
            writeLE16(dsGy, into: &report, at: 18)
            writeLE16(dsGz, into: &report, at: 20)
            
            writeLE16(dsAx, into: &report, at: 22)
            writeLE16(dsAy, into: &report, at: 24)
            writeLE16(dsAz, into: &report, at: 26)
        }
        
        // Bytes 28..31: Sensor Clock Tick
        let clockTick = UInt32(truncatingIfNeeded: UInt64(state.timestamp * 1_000_000))
        report[28] = UInt8(clockTick & 0xFF)
        report[29] = UInt8((clockTick >> 8) & 0xFF)
        report[30] = UInt8((clockTick >> 16) & 0xFF)
        report[31] = UInt8((clockTick >> 24) & 0xFF)
        
        // Bytes 33 & 37: Touchpad contacts inactive (0x80)
        report[33] = 0x80
        report[37] = 0x80
        
        // Byte 53: Battery status (0x2A = USB connected, fully charged 100%)
        report[53] = 0x2A
        report[54] = 0x08
        
        return Data(report)
    }
    
    // MARK: - Helpers
    
    private func axisToUInt8(_ val: Float) -> UInt8 {
        let clamped = max(-1.0, min(1.0, val))
        let scaled = (clamped + 1.0) * 127.5
        return UInt8(max(0, min(255, Int(scaled.rounded()))))
    }
    
    private func applyDeadzone(_ val: Float, deadzone: Float) -> Float {
        let mag = abs(val)
        guard mag > deadzone else { return 0.0 }
        let sign: Float = val > 0 ? 1.0 : -1.0
        return sign * ((mag - deadzone) / (1.0 - deadzone))
    }
    
    private func applyTriggerDeadzone(_ val: Float, deadzone: Float) -> Float {
        guard val > deadzone else { return 0.0 }
        return (val - deadzone) / (1.0 - deadzone)
    }
    
    private func writeLE16(_ val: Int16, into buffer: inout [UInt8], at index: Int) {
        let uVal = UInt16(bitPattern: val)
        buffer[index] = UInt8(uVal & 0xFF)
        buffer[index + 1] = UInt8((uVal >> 8) & 0xFF)
    }
}
