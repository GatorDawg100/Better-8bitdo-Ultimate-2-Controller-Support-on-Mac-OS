import Foundation
import CoreGraphics
import simd

/// Decodes raw 34-byte Report ID 1 packets from the 8BitDo Ultimate 2 Wireless Controller into `EightBitDoState`.
public final class EightBitDoPacketDecoder: @unchecked Sendable {
    private var filterPitch: Double = 0.0
    private var filterRoll: Double = 0.0
    private var filterYaw: Double = 0.0
    private var lastTimestamp: Double = 0.0
    private var reportCount: UInt64 = 0
    
    private let lock = NSLock()
    
    public init() {}
    
    public func resetOrientation() {
        lock.lock()
        defer { lock.unlock() }
        filterPitch = 0.0
        filterRoll = 0.0
        filterYaw = 0.0
        reportCount = 0
        lastTimestamp = 0.0
    }
    
    public func decode(data: Data, timestamp: TimeInterval = ProcessInfo.processInfo.systemUptime) -> EightBitDoState? {
        guard data.count >= 27 else { return nil }
        
        return data.withUnsafeBytes { rawBuffer -> EightBitDoState? in
            guard let bytes = rawBuffer.bindMemory(to: UInt8.self).baseAddress else { return nil }
            
            // Byte 1: D-Pad Hat Switch (0=Up, 1=UR, 2=R, 3=DR, 4=D, 5=DL, 6=L, 7=UL, 15=None)
            let hat = bytes[1]
            let dpadUp = (hat == 0 || hat == 1 || hat == 7)
            let dpadRight = (hat == 1 || hat == 2 || hat == 3)
            let dpadDown = (hat == 3 || hat == 4 || hat == 5)
            let dpadLeft = (hat == 5 || hat == 6 || hat == 7)
            
            // Bytes 2..5: Thumbsticks (0..255, center = 127.5)
            // Left Stick: Byte 2 = X, Byte 3 = Y (inverted so UP is positive)
            let rawLX = Float(bytes[2])
            let rawLY = Float(bytes[3])
            let lx = (rawLX - EightBitDoConstants.stickCenter) / EightBitDoConstants.stickCenter
            let ly = -(rawLY - EightBitDoConstants.stickCenter) / EightBitDoConstants.stickCenter
            
            // Right Stick: Byte 4 = X, Byte 5 = Y (inverted so UP is positive)
            let rawRX = Float(bytes[4])
            let rawRY = Float(bytes[5])
            let rx = (rawRX - EightBitDoConstants.stickCenter) / EightBitDoConstants.stickCenter
            let ry = -(rawRY - EightBitDoConstants.stickCenter) / EightBitDoConstants.stickCenter
            
            // Byte 6: Face buttons & Bumpers
            let b6 = bytes[6]
            let btnA = (b6 & (1 << 0)) != 0
            let btnB = (b6 & (1 << 1)) != 0
            let btnX = (b6 & (1 << 3)) != 0
            let btnY = (b6 & (1 << 4)) != 0
            let btnLB = (b6 & (1 << 6)) != 0
            let btnRB = (b6 & (1 << 7)) != 0
            
            // Byte 7: System & Stick Click buttons
            let b7 = bytes[7]
            let btnSelect = (b7 & (1 << 2)) != 0
            let btnStart = (b7 & (1 << 3)) != 0
            let btnHome = (b7 & (1 << 4)) != 0
            let btnL3 = (b7 & (1 << 5)) != 0
            let btnR3 = (b7 & (1 << 6)) != 0
            
            // Bytes 8 & 9: Analog Triggers (0..255)
            let lt = Float(bytes[8]) / 255.0
            let rt = Float(bytes[9]) / 255.0
            
            // Byte 10: Back Paddles (M1 = bit 0, M2 = bit 1)
            var pM1 = false
            var pM2 = false
            if data.count > 10 {
                let b10 = bytes[10]
                pM1 = (b10 & 0x01) != 0
                pM2 = (b10 & 0x02) != 0
            }
            
            // Bytes 15..20: 3-Axis Accelerometer (16-bit signed LE, ~4096 LSB/g)
            let rawAx = Int16(bitPattern: UInt16(bytes[15]) | (UInt16(bytes[16]) << 8))
            let rawAy = Int16(bitPattern: UInt16(bytes[17]) | (UInt16(bytes[18]) << 8))
            let rawAz = Int16(bitPattern: UInt16(bytes[19]) | (UInt16(bytes[20]) << 8))
            
            // Bytes 21..26: 3-Axis Gyroscope (16-bit signed LE, ~16.384 LSB/(deg/s))
            let rawGx = Int16(bitPattern: UInt16(bytes[21]) | (UInt16(bytes[22]) << 8))
            let rawGy = Int16(bitPattern: UInt16(bytes[23]) | (UInt16(bytes[24]) << 8))
            let rawGz = Int16(bitPattern: UInt16(bytes[25]) | (UInt16(bytes[26]) << 8))
            
            let ax = Float(rawAx) / EightBitDoConstants.accelScale
            let ay = Float(rawAy) / EightBitDoConstants.accelScale
            let az = Float(rawAz) / EightBitDoConstants.accelScale
            
            let gxDeg = Float(rawGx) * EightBitDoConstants.gyroScaleDegPerLSB
            let gyDeg = Float(rawGy) * EightBitDoConstants.gyroScaleDegPerLSB
            let gzDeg = Float(rawGz) * EightBitDoConstants.gyroScaleDegPerLSB
            
            let gxRad = Float(rawGx) * EightBitDoConstants.gyroScaleRadPerLSB
            let gyRad = Float(rawGy) * EightBitDoConstants.gyroScaleRadPerLSB
            let gzRad = Float(rawGz) * EightBitDoConstants.gyroScaleRadPerLSB
            
            // Sensor Fusion (Complementary Filter)
            self.lock.lock()
            let dt: Double
            if self.lastTimestamp == 0.0 {
                dt = 0.016
            } else {
                dt = min(0.1, max(0.001, timestamp - self.lastTimestamp))
            }
            self.lastTimestamp = timestamp
            self.reportCount += 1
            
            let accelPitch = atan2(Double(ay), sqrt(Double(ax * ax + az * az)))
            let accelRoll = atan2(-Double(ax), Double(az))
            
            if self.reportCount <= 2 {
                self.filterPitch = accelPitch
                self.filterRoll = accelRoll
            } else {
                let alpha = 0.92
                self.filterPitch = alpha * (self.filterPitch + Double(gxRad) * dt) + (1.0 - alpha) * accelPitch
                self.filterRoll = alpha * (self.filterRoll + Double(gyRad) * dt) + (1.0 - alpha) * accelRoll
                self.filterYaw += Double(gzRad) * dt
            }
            
            let currentPitch = Float(self.filterPitch * (180.0 / .pi))
            let currentRoll = Float(self.filterRoll * (180.0 / .pi))
            let currentYaw = Float(self.filterYaw * (180.0 / .pi))
            let index = self.reportCount
            self.lock.unlock()
            
            let rawGrav = SIMD3<Float>(ax, ay, az)
            let gravNorm = simd_length(rawGrav) > 0.001 ? simd_normalize(rawGrav) : SIMD3<Float>(0, 0, -1)
            
            return EightBitDoState(
                leftStick: CGPoint(x: CGFloat(lx), y: CGFloat(ly)),
                rightStick: CGPoint(x: CGFloat(rx), y: CGFloat(ry)),
                leftTrigger: lt,
                rightTrigger: rt,
                buttonA: btnA,
                buttonB: btnB,
                buttonX: btnX,
                buttonY: btnY,
                buttonLB: btnLB,
                buttonRB: btnRB,
                buttonL3: btnL3,
                buttonR3: btnR3,
                buttonSelect: btnSelect,
                buttonStart: btnStart,
                buttonHome: btnHome,
                dpadUp: dpadUp,
                dpadDown: dpadDown,
                dpadLeft: dpadLeft,
                dpadRight: dpadRight,
                paddleM1: pM1,
                paddleM2: pM2,
                acceleration: rawGrav,
                angularVelocityDeg: SIMD3<Float>(gxDeg, gyDeg, gzDeg),
                angularVelocityRad: SIMD3<Float>(gxRad, gyRad, gzRad),
                gravity: gravNorm,
                pitch: currentPitch,
                roll: currentRoll,
                yaw: currentYaw,
                timestamp: timestamp,
                reportIndex: index
            )
        }
    }
}
