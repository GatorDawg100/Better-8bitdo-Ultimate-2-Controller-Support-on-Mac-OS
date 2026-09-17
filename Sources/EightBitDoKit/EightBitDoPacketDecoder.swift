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
            
            // Flexible base index: 1 if prepended with Report ID 0x01, 0 otherwise
            let base: Int = (bytes[0] == EightBitDoConstants.inputReportID && data.count >= 34) ? 1 : 0
            guard data.count >= (base + 26) else { return nil }
            
            // D-Pad Hat Switch (0=Up, 1=UR, 2=R, 3=DR, 4=D, 5=DL, 6=L, 7=UL, 15=None)
            let hat = bytes[base + 0] & 0x0F
            let dpadUp = (hat == 0 || hat == 1 || hat == 7)
            let dpadRight = (hat == 1 || hat == 2 || hat == 3)
            let dpadDown = (hat == 3 || hat == 4 || hat == 5)
            let dpadLeft = (hat == 5 || hat == 6 || hat == 7)
            
            // Thumbsticks (0..255, center = 127.5)
            // Left Stick: X, Y (inverted so UP is positive)
            let rawLX = Float(bytes[base + 1])
            let rawLY = Float(bytes[base + 2])
            let lx = (rawLX - EightBitDoConstants.stickCenter) / EightBitDoConstants.stickCenter
            let ly = -(rawLY - EightBitDoConstants.stickCenter) / EightBitDoConstants.stickCenter
            
            // Right Stick: X, Y (inverted so UP is positive)
            let rawRX = Float(bytes[base + 3])
            let rawRY = Float(bytes[base + 4])
            let rx = (rawRX - EightBitDoConstants.stickCenter) / EightBitDoConstants.stickCenter
            let ry = -(rawRY - EightBitDoConstants.stickCenter) / EightBitDoConstants.stickCenter
            
            // Analog Triggers (0..255, Byte 6 = Accelerator / LT, Byte 7 = Brake / RT)
            let lt = Float(bytes[base + 5]) / 255.0
            let rt = Float(bytes[base + 6]) / 255.0
            
            // Byte 8 (base + 7): Face buttons, Bumpers & Back Paddles
            // Hardware mapping: A=bit0, B=bit1, M2=bit2, X=bit3, Y=bit4, M1=bit5, LB=bit6, RB=bit7
            let b8 = bytes[base + 7]
            let btnA = (b8 & (1 << 0)) != 0
            let btnB = (b8 & (1 << 1)) != 0
            let pM2 = (b8 & (1 << 2)) != 0 // Back Paddle M2 (Right)
            let btnX = (b8 & (1 << 3)) != 0
            let btnY = (b8 & (1 << 4)) != 0
            let pM1 = (b8 & (1 << 5)) != 0 // Back Paddle M1 (Left)
            let btnLB = (b8 & (1 << 6)) != 0
            let btnRB = (b8 & (1 << 7)) != 0
            
            // Byte 9 (base + 8): System buttons & Thumbstick clicks
            // Hardware mapping: Select=bit2, Start=bit3, Home=bit4, L3=bit5, R3=bit6
            let b9 = bytes[base + 8]
            let btnSelect = (b9 & (1 << 2)) != 0
            let btnStart = (b9 & (1 << 3)) != 0
            var btnHome = (b9 & (1 << 4)) != 0
            let btnL3 = (b9 & (1 << 5)) != 0
            let btnR3 = (b9 & (1 << 6)) != 0
            
            // Byte 10 (base + 9): Extra Bumpers (L4 & R4)
            // Hardware mapping: L4=bit0, R4=bit1
            var btnL4 = false
            var btnR4 = false
            if data.count > (base + 9) {
                let b10 = bytes[base + 9]
                btnL4 = (b10 & (1 << 0)) != 0 // Extra Bumper L4 (Left)
                btnR4 = (b10 & (1 << 1)) != 0 // Extra Bumper R4 (Right)
                if (b10 & (1 << 4)) != 0 || (b10 & (1 << 5)) != 0 {
                    btnHome = true
                }
            }
            
            // 3-Axis Accelerometer (16-bit signed LE, ~4096 LSB/g)
            let rawAx = Int16(bitPattern: UInt16(bytes[base + 14]) | (UInt16(bytes[base + 15]) << 8))
            let rawAy = Int16(bitPattern: UInt16(bytes[base + 16]) | (UInt16(bytes[base + 17]) << 8))
            let rawAz = Int16(bitPattern: UInt16(bytes[base + 18]) | (UInt16(bytes[base + 19]) << 8))
            
            // 3-Axis Gyroscope (16-bit signed LE, ~16.384 LSB/(deg/s))
            let rawGx = Int16(bitPattern: UInt16(bytes[base + 20]) | (UInt16(bytes[base + 21]) << 8))
            let rawGy = Int16(bitPattern: UInt16(bytes[base + 22]) | (UInt16(bytes[base + 23]) << 8))
            let rawGz = Int16(bitPattern: UInt16(bytes[base + 24]) | (UInt16(bytes[base + 25]) << 8))
            
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
            
            // Swapped axes per user request:
            // Pitch: controlled by tilting left / right around lateral axis
            let accelPitch = atan2(-Double(ax), sqrt(Double(ay * ay + az * az)))
            // Roll: controlled by tilting forward / backward around longitudinal axis
            let accelRoll = atan2(Double(ay), sqrt(Double(ax * ax + az * az)))
            
            if self.reportCount <= 5 {
                self.filterPitch = accelPitch
                self.filterRoll = accelRoll
            } else {
                let alpha = 0.94
                self.filterPitch = alpha * (self.filterPitch + Double(gyRad) * dt) + (1.0 - alpha) * accelPitch
                self.filterRoll = alpha * (self.filterRoll + Double(gxRad) * dt) + (1.0 - alpha) * accelRoll
                self.filterYaw += Double(gzRad) * dt
            }
            
            let currentPitch = Float(self.filterPitch * (180.0 / .pi))
            let currentRoll = Float(self.filterRoll * (180.0 / .pi))
            let currentYaw = Float(self.filterYaw * (180.0 / .pi))
            let index = self.reportCount
            self.lock.unlock()
            
            let rawGrav = SIMD3<Float>(ax, ay, az)
            let gravNorm = simd_length(rawGrav) > 0.001 ? simd_normalize(rawGrav) : SIMD3<Float>(0, 0, 1)
            
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
                buttonL4: btnL4,
                buttonR4: btnR4,
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
