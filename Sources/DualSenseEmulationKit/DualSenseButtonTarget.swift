import Foundation

/// Target button on the emulated DualSense controller.
public enum DualSenseButtonTarget: String, CaseIterable, Codable, Sendable, Identifiable {
    case cross = "Cross (✕ / A)"
    case circle = "Circle (○ / B)"
    case square = "Square (□ / X)"
    case triangle = "Triangle (△ / Y)"
    
    case l1 = "L1 (Left Bumper)"
    case r1 = "R1 (Right Bumper)"
    case l2 = "L2 (Left Trigger Click)"
    case r2 = "R2 (Right Trigger Click)"
    
    case l3 = "L3 (Left Stick Click)"
    case r3 = "R3 (Right Stick Click)"
    
    case create = "Create (Share / Select)"
    case options = "Options (Start)"
    case ps = "PS Button (Home)"
    
    case touchpad = "Touchpad Click"
    case mute = "Mute Button"
    
    case dpadUp = "D-Pad Up"
    case dpadDown = "D-Pad Down"
    case dpadLeft = "D-Pad Left"
    case dpadRight = "D-Pad Right"
    
    case none = "None (Disabled)"
    
    public var id: String { rawValue }
    
    public var shortName: String {
        switch self {
        case .cross: return "✕ Cross"
        case .circle: return "○ Circle"
        case .square: return "□ Square"
        case .triangle: return "△ Triangle"
        case .l1: return "L1"
        case .r1: return "R1"
        case .l2: return "L2"
        case .r2: return "R2"
        case .l3: return "L3"
        case .r3: return "R3"
        case .create: return "Create"
        case .options: return "Options"
        case .ps: return "PS"
        case .touchpad: return "Touchpad"
        case .mute: return "Mute"
        case .dpadUp: return "D-Up"
        case .dpadDown: return "D-Down"
        case .dpadLeft: return "D-Left"
        case .dpadRight: return "D-Right"
        case .none: return "Disabled"
        }
    }
}
