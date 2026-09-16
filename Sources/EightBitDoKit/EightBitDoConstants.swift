import Foundation

public enum EightBitDoConstants {
    /// 8BitDo USB Vendor ID
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
    
    /// Neutral center stick value
    public static let stickCenter: Float = 127.5
}
