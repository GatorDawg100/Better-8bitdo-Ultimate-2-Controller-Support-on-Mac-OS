import Foundation

public enum EightBitDoConstants {
    /// 8BitDo USB Vendor ID (0x2DC8)
    public static let vendorID: Int = 0x2DC8
    
    /// 8BitDo Ultimate 2 Wireless Controller Product ID (in 2.4G / D-Input mode)
    public static let productID: Int = 0x6012
    
    /// Alternate 8BitDo Product IDs with compatible reports
    public static let supportedProductIDs: Set<Int> = [
        0x6012, // Ultimate 2 2.4G D-Input
        0x3106, // Ultimate C Wireless
        0x3012  // Ultimate Wireless v1
    ]
    
    /// Input Report ID for telemetry, buttons, sticks, IMU
    public static let inputReportID: UInt8 = 0x01
    public static let inputReportLength: Int = 34
    
    /// Output Report ID for force feedback vibration / rumble
    public static let outputReportID: UInt8 = 0x05
    public static let outputReportLength: Int = 4
    
    /// Accelerometer scale factor: ~4096 LSB per 1.0g
    public static let accelScale: Float = 4096.0
    
    /// Gyroscope scale factor: ~16.384 LSB per deg/s (0.061035 deg/s per LSB)
    public static let gyroScaleDegPerLSB: Float = 0.061035
    public static let gyroScaleRadPerLSB: Float = 0.061035 * (Float.pi / 180.0)
    
    /// Neutral center stick raw value
    public static let stickCenter: Float = 127.5
    
    /// Byte offsets within Input Report 1 (relative to start of report payload after report ID 0x01)
    public enum InputReportOffset {
        /// D-pad hat switch nibble (0=Up, 1=UR, 2=R, 3=DR, 4=D, 5=DL, 6=L, 7=UL, 15=None)
        public static let dpadHat = 0
        /// Left thumbstick horizontal X axis (0..255, 128 neutral)
        public static let leftStickX = 1
        /// Left thumbstick vertical Y axis (0..255, 128 neutral, inverted)
        public static let leftStickY = 2
        /// Right thumbstick horizontal X axis (0..255, 128 neutral)
        public static let rightStickX = 3
        /// Right thumbstick vertical Y axis (0..255, 128 neutral, inverted)
        public static let rightStickY = 4
        /// Left analog trigger LT (0..255)
        public static let leftTrigger = 5
        /// Right analog trigger RT (0..255)
        public static let rightTrigger = 6
        /// Face buttons, bumpers & back paddles (A, B, M2, X, Y, M1, LB, RB)
        public static let buttonsMain = 7
        /// System buttons & stick clicks (Select, Start, Home, L3, R3)
        public static let buttonsSystem = 8
        /// Extra bumper buttons (L4, R4)
        public static let buttonsExtraBumpers = 9
        /// 3-Axis Accelerometer X, Y, Z (16-bit signed LE, bytes 14..19)
        public static let accelX = 14
        public static let accelY = 16
        public static let accelZ = 18
        /// 3-Axis Gyroscope X, Y, Z (16-bit signed LE, bytes 20..25)
        public static let gyroX = 20
        public static let gyroY = 22
        public static let gyroZ = 24
    }
    
    /// Bitmasks for Byte 8 (base + 7): Face buttons, Bumpers & Back Paddles
    public enum Byte8Bitmask {
        public static let buttonA: UInt8  = 1 << 0
        public static let buttonB: UInt8  = 1 << 1
        public static let paddleM2: UInt8 = 1 << 2 // Right back paddle
        public static let buttonX: UInt8  = 1 << 3
        public static let buttonY: UInt8  = 1 << 4
        public static let paddleM1: UInt8 = 1 << 5 // Left back paddle
        public static let buttonLB: UInt8 = 1 << 6
        public static let buttonRB: UInt8 = 1 << 7
    }
    
    /// Bitmasks for Byte 9 (base + 8): System navigation & Thumbstick clicks
    public enum Byte9Bitmask {
        public static let select: UInt8 = 1 << 2
        public static let start: UInt8  = 1 << 3
        public static let home: UInt8   = 1 << 4
        public static let l3: UInt8     = 1 << 5
        public static let r3: UInt8     = 1 << 6
    }
    
    /// Bitmasks for Byte 10 (base + 9): Extra Bumpers
    public enum Byte10Bitmask {
        public static let buttonL4: UInt8 = 1 << 0 // Left extra bumper
        public static let buttonR4: UInt8 = 1 << 1 // Right extra bumper
    }
}
