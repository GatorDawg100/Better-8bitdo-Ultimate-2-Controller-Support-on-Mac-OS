import Foundation
import EightBitDoKit

/// Complete customization and button mapping profile for translating 8BitDo Ultimate 2 inputs to DualSense 5.
public struct RemappingProfile: Codable, Equatable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var name: String
    
    // Button mapping table
    public var buttonMap: [EightBitDoButton: DualSenseButtonTarget]
    
    // Deadzones & Response
    public var leftStickDeadzone: Float
    public var rightStickDeadzone: Float
    public var triggerDeadzone: Float
    public var hairTriggers: Bool
    
    // Motion / Gyroscope
    public var gyroEnabled: Bool
    public var gyroSensitivity: Float
    public var gyroInvertX: Bool
    public var gyroInvertY: Bool
    
    // Haptics & Vibration
    public var rumbleEnabled: Bool
    public var rumbleMultiplier: Float
    
    public init(
        id: UUID = UUID(),
        name: String = "Standard DualSense",
        buttonMap: [EightBitDoButton: DualSenseButtonTarget]? = nil,
        leftStickDeadzone: Float = 0.05,
        rightStickDeadzone: Float = 0.05,
        triggerDeadzone: Float = 0.05,
        hairTriggers: Bool = false,
        gyroEnabled: Bool = true,
        gyroSensitivity: Float = 1.0,
        gyroInvertX: Bool = false,
        gyroInvertY: Bool = false,
        rumbleEnabled: Bool = true,
        rumbleMultiplier: Float = 1.0
    ) {
        self.id = id
        self.name = name
        self.leftStickDeadzone = leftStickDeadzone
        self.rightStickDeadzone = rightStickDeadzone
        self.triggerDeadzone = triggerDeadzone
        self.hairTriggers = hairTriggers
        self.gyroEnabled = gyroEnabled
        self.gyroSensitivity = gyroSensitivity
        self.gyroInvertX = gyroInvertX
        self.gyroInvertY = gyroInvertY
        self.rumbleEnabled = rumbleEnabled
        self.rumbleMultiplier = rumbleMultiplier
        
        if let map = buttonMap {
            self.buttonMap = map
        } else {
            // Default 1:1 layout with M1 mapped to Touchpad and M2 mapped to L3
            self.buttonMap = [
                .a: .cross,
                .b: .circle,
                .x: .square,
                .y: .triangle,
                .lb: .l1,
                .rb: .r1,
                .lt: .l2,
                .rt: .r2,
                .l3: .l3,
                .r3: .r3,
                .select: .create,
                .start: .options,
                .home: .ps,
                .dpadUp: .dpadUp,
                .dpadDown: .dpadDown,
                .dpadLeft: .dpadLeft,
                .dpadRight: .dpadRight,
                .paddleM1: .touchpad,   // Touchpad Click (essential for PlayStation games!)
                .paddleM2: .l3          // Sprint / L3
            ]
        }
    }
    
    /// Maps an 8BitDo physical input to its DualSense target
    public func target(for button: EightBitDoButton) -> DualSenseButtonTarget {
        buttonMap[button] ?? .none
    }
    
    // MARK: - Built-in Presets
    
    public static let standard = RemappingProfile(
        name: "Standard DualSense (M1=Touchpad)"
    )
    
    public static let nintendo = RemappingProfile(
        name: "Nintendo Layout (Swap A/B & X/Y)",
        buttonMap: [
            .a: .circle,    // Physical A (East) -> Circle (East)
            .b: .cross,     // Physical B (South) -> Cross (South)
            .x: .triangle,  // Physical X (North) -> Triangle (North)
            .y: .square,    // Physical Y (West) -> Square (West)
            .lb: .l1,
            .rb: .r1,
            .lt: .l2,
            .rt: .r2,
            .l3: .l3,
            .r3: .r3,
            .select: .create,
            .start: .options,
            .home: .ps,
            .dpadUp: .dpadUp,
            .dpadDown: .dpadDown,
            .dpadLeft: .dpadLeft,
            .dpadRight: .dpadRight,
            .paddleM1: .touchpad,
            .paddleM2: .l3
        ]
    )
    
    public static let soulsborne = RemappingProfile(
        name: "Action / Soulsborne (M1=Dodge, M2=Run)",
        buttonMap: [
            .a: .cross,
            .b: .circle,
            .x: .square,
            .y: .triangle,
            .lb: .l1,
            .rb: .r1,
            .lt: .l2,
            .rt: .r2,
            .l3: .l3,
            .r3: .r3,
            .select: .create,
            .start: .options,
            .home: .ps,
            .dpadUp: .dpadUp,
            .dpadDown: .dpadDown,
            .dpadLeft: .dpadLeft,
            .dpadRight: .dpadRight,
            .paddleM1: .circle, // Dodge / Roll without taking thumb off right stick!
            .paddleM2: .l3     // Sprint
        ]
    )
    
    public static let fpsPro = RemappingProfile(
        name: "FPS Pro (M1=Jump, M2=Crouch, Hair-Triggers)",
        buttonMap: [
            .a: .cross,
            .b: .circle,
            .x: .square,
            .y: .triangle,
            .lb: .l1,
            .rb: .r1,
            .lt: .l2,
            .rt: .r2,
            .l3: .l3,
            .r3: .r3,
            .select: .create,
            .start: .options,
            .home: .ps,
            .dpadUp: .dpadUp,
            .dpadDown: .dpadDown,
            .dpadLeft: .dpadLeft,
            .dpadRight: .dpadRight,
            .paddleM1: .cross,  // Jump
            .paddleM2: .circle  // Crouch / Slide
        ],
        hairTriggers: true
    )
    
    public static let defaultPresets: [RemappingProfile] = [
        .standard,
        .nintendo,
        .soulsborne,
        .fpsPro
    ]
}
