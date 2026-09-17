import Foundation
import CoreGraphics
import simd

/// Decodes raw 34-byte Report ID 1 packets from the 8BitDo Ultimate 2 Wireless Controller into `EightBitDoState`.
public final class EightBitDoPacketDecoder: @unchecked Sendable {
    
    /// User-configurable tuning parameters for filtering and axis interpretation.
    public struct Configuration: Sendable, Equatable {
        /// Weight of gyro integration vs accelerometer reference in complementary filter (0.0 to 1.0)
        public var complementaryFilterAlpha: Double
        
        /// Invert estimated attitude pitch
        public var invertPitch: Bool
        
        /// Invert estimated attitude roll
        public var invertRoll: Bool
        
        /// Invert estimated attitude yaw
        public var invertYaw: Bool
        
        /// Whether to automatically track and cancel stationary gyro zero-rate drift bias
        public var autoZeroGyroBias: Bool
        
        /// Acceleration tolerance from 1.0g to qualify as stationary
        public var restingGravityToleranceG: Float
        
        /// Maximum angular rate (deg/s) on each axis to qualify as stationary
        public var restingAngularVelocityThresholdDeg: Float
        
        /// Stationary duration required before beginning bias convergence (in seconds)
        public var stationaryDurationRequired: TimeInterval
        
        public init(
            complementaryFilterAlpha: Double = 0.94,
            invertPitch: Bool = false,
            invertRoll: Bool = false,
            invertYaw: Bool = false,
            autoZeroGyroBias: Bool = true,
            restingGravityToleranceG: Float = 0.08,
            restingAngularVelocityThresholdDeg: Float = 2.0,
            stationaryDurationRequired: TimeInterval = 0.35
        ) {
            self.complementaryFilterAlpha = complementaryFilterAlpha
            self.invertPitch = invertPitch
            self.invertRoll = invertRoll
            self.invertYaw = invertYaw
            self.autoZeroGyroBias = autoZeroGyroBias
            self.restingGravityToleranceG = restingGravityToleranceG
            self.restingAngularVelocityThresholdDeg = restingAngularVelocityThresholdDeg
            self.stationaryDurationRequired = stationaryDurationRequired
        }
    }
    
    private var filterPitch: Double = 0.0
    private var filterRoll: Double = 0.0
    private var filterYaw: Double = 0.0
    private var lastTimestamp: Double = 0.0
    private var reportCount: UInt64 = 0
    private var gyroBiasDeg: SIMD3<Float> = .zero
    private var stationarySince: TimeInterval = 0.0
    private var config: Configuration = Configuration()
    
    private let lock = NSLock()
    
    public init(configuration: Configuration = Configuration()) {
        self.config = configuration
    }
    
    /// Current decoder configuration
    public var configuration: Configuration {
        get {
            lock.lock()
            defer { lock.unlock() }
            return config
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            config = newValue
        }
    }
    
    /// Estimated stationary zero-rate gyroscope bias in deg/s (X, Y, Z)
    public var currentGyroBiasDeg: SIMD3<Float> {
        lock.lock()
        defer { lock.unlock() }
        return gyroBiasDeg
    }
    
    /// Resets the estimated attitude and zeros the accumulated yaw
    public func resetOrientation(pitch: Float = 0, roll: Float = 0, yaw: Float = 0) {
        lock.lock()
        defer { lock.unlock() }
        filterPitch = Double(pitch) * (.pi / 180.0)
        filterRoll = Double(roll) * (.pi / 180.0)
        filterYaw = Double(yaw) * (.pi / 180.0)
        reportCount = 0
        lastTimestamp = 0.0
    }
    
    /// Resets the estimated stationary gyro zero-rate bias to zero
    public func resetGyroBias() {
        lock.lock()
        defer { lock.unlock() }
        gyroBiasDeg = .zero
        stationarySince = 0.0
    }
    
    /// Sets a manual gyro bias offset in deg/s
    public func setGyroBias(deg: SIMD3<Float>) {
        lock.lock()
        defer { lock.unlock() }
        gyroBiasDeg = deg
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
            
            var gxDeg = Float(rawGx) * EightBitDoConstants.gyroScaleDegPerLSB
            var gyDeg = Float(rawGy) * EightBitDoConstants.gyroScaleDegPerLSB
            var gzDeg = Float(rawGz) * EightBitDoConstants.gyroScaleDegPerLSB
            
            // Sensor Fusion (Complementary Filter) & Stationary Drift Bias Estimation
            self.lock.lock()
            
            if self.config.autoZeroGyroBias {
                let accelMag = sqrt(ax * ax + ay * ay + az * az)
                let isStationary = abs(accelMag - 1.0) < self.config.restingGravityToleranceG &&
                                   abs(gxDeg) < self.config.restingAngularVelocityThresholdDeg &&
                                   abs(gyDeg) < self.config.restingAngularVelocityThresholdDeg &&
                                   abs(gzDeg) < self.config.restingAngularVelocityThresholdDeg
                
                if isStationary {
                    if self.stationarySince == 0 {
                        self.stationarySince = timestamp
                    } else if (timestamp - self.stationarySince) >= self.config.stationaryDurationRequired {
                        // Slowly adapt stationary zero-bias offset
                        let biasAlpha: Float = 0.02
                        self.gyroBiasDeg.x = self.gyroBiasDeg.x * (1.0 - biasAlpha) + gxDeg * biasAlpha
                        self.gyroBiasDeg.y = self.gyroBiasDeg.y * (1.0 - biasAlpha) + gyDeg * biasAlpha
                        self.gyroBiasDeg.z = self.gyroBiasDeg.z * (1.0 - biasAlpha) + gzDeg * biasAlpha
                    }
                } else {
                    self.stationarySince = 0
                }
            }
            
            // Subtract stationary bias
            gxDeg -= self.gyroBiasDeg.x
            gyDeg -= self.gyroBiasDeg.y
            gzDeg -= self.gyroBiasDeg.z
            
            let gxRad = gxDeg * (Float.pi / 180.0)
            let gyRad = gyDeg * (Float.pi / 180.0)
            let gzRad = gzDeg * (Float.pi / 180.0)
            
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
                let alpha = self.config.complementaryFilterAlpha
                self.filterPitch = alpha * (self.filterPitch + Double(gyRad) * dt) + (1.0 - alpha) * accelPitch
                self.filterRoll = alpha * (self.filterRoll + Double(gxRad) * dt) + (1.0 - alpha) * accelRoll
                self.filterYaw += Double(gzRad) * dt
            }
            
            var currentPitch = Float(self.filterPitch * (180.0 / .pi))
            var currentRoll = Float(self.filterRoll * (180.0 / .pi))
            var currentYaw = Float(self.filterYaw * (180.0 / .pi))
            
            if self.config.invertPitch { currentPitch = -currentPitch }
            if self.config.invertRoll { currentRoll = -currentRoll }
            if self.config.invertYaw { currentYaw = -currentYaw }
            
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
