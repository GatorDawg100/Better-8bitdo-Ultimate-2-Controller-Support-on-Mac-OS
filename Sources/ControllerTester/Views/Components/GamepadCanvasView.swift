import SwiftUI

public struct GamepadCanvasView: View {
    @ObservedObject var state: GamepadState
    @ObservedObject var hapticsManager: HapticsManager
    
    public init(state: GamepadState, hapticsManager: HapticsManager) {
        self.state = state
        self.hapticsManager = hapticsManager
    }
    
    public var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let scale = min(w / 640.0, h / 420.0)
            
            ZStack {
                // Background subtle vignette
                RadialGradient(
                    colors: [Color.accentColor.opacity(0.08), Color.clear],
                    center: .center,
                    startRadius: 50,
                    endRadius: 300
                )
                
                // Controller Container scaled and centered
                ZStack {
                    // Controller Outer Body Shape
                    ControllerChassisPath()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(nsColor: .windowBackgroundColor).opacity(0.95),
                                    Color(nsColor: .controlBackgroundColor).opacity(0.9)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay(
                            ControllerChassisPath()
                                .stroke(Color.secondary.opacity(0.35), lineWidth: 2)
                        )
                        .shadow(color: Color.black.opacity(0.3), radius: 18, x: 0, y: 10)
                    
                    // Top Shoulders & Triggers
                    ShouldersAndTriggersOverlay(state: state)
                        .offset(y: -140)
                    
                    // Center System Buttons (Menu, Options/Share, Home)
                    CenterSystemButtons(state: state)
                        .offset(y: -40)
                    
                    // D-Pad (Left side)
                    DpadModuleView(state: state)
                        .offset(x: -150, y: 30)
                    
                    // Left Thumbstick
                    ThumbstickModuleView(
                        title: "LS",
                        stick: state.leftStick,
                        isPressed: state.leftStickButton.isPressed,
                        accentColor: .blue
                    )
                    .offset(x: -80, y: -30)
                    
                    // Right Action Buttons (A, B, X, Y)
                    ActionButtonsModuleView(state: state)
                        .offset(x: 150, y: -30)
                    
                    // Right Thumbstick
                    ThumbstickModuleView(
                        title: "RS",
                        stick: state.rightStick,
                        isPressed: state.rightStickButton.isPressed,
                        accentColor: .purple
                    )
                    .offset(x: 75, y: 40)
                }
                .frame(width: 580, height: 380)
                .scaleEffect(scale)
                .rotation3DEffect(
                    .degrees(state.motion.hasMotion ? state.motion.pitch * 180.0 / .pi * 0.25 : 0),
                    axis: (x: 1, y: 0, z: 0)
                )
                .rotation3DEffect(
                    .degrees(state.motion.hasMotion ? -state.motion.roll * 180.0 / .pi * 0.25 : 0),
                    axis: (x: 0, y: 1, z: 0)
                )
                // Shake effect if vibrating
                .offset(
                    x: hapticsManager.isVibrating ? CGFloat.random(in: -2...2) : 0,
                    y: hapticsManager.isVibrating ? CGFloat.random(in: -2...2) : 0
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Controller Chassis Vector Path
private struct ControllerChassisPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        // Normalized coordinate space 580 x 380
        let w = rect.width
        let h = rect.height
        
        let sx = w / 580.0
        let sy = h / 380.0
        
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: x * sx, y: y * sy)
        }
        
        path.move(to: p(160, 40))
        // Top edge center indentation
        path.addCurve(to: p(290, 55), control1: p(200, 42), control2: p(250, 55))
        path.addCurve(to: p(420, 40), control1: p(330, 55), control2: p(380, 42))
        
        // Right shoulder curve
        path.addCurve(to: p(520, 110), control1: p(480, 40), control2: p(520, 70))
        // Right outer grip
        path.addCurve(to: p(540, 270), control1: p(520, 150), control2: p(555, 210))
        path.addCurve(to: p(470, 360), control1: p(530, 320), control2: p(510, 360))
        // Right inner grip
        path.addCurve(to: p(360, 260), control1: p(420, 360), control2: p(390, 290))
        
        // Bottom center groove
        path.addCurve(to: p(290, 275), control1: p(330, 230), control2: p(310, 275))
        path.addCurve(to: p(220, 260), control1: p(270, 275), control2: p(250, 230))
        
        // Left inner grip
        path.addCurve(to: p(110, 360), control1: p(190, 290), control2: p(160, 360))
        // Left outer grip
        path.addCurve(to: p(40, 270), control1: p(70, 360), control2: p(50, 320))
        path.addCurve(to: p(60, 110), control1: p(25, 210), control2: p(60, 150))
        // Left shoulder curve
        path.addCurve(to: p(160, 40), control1: p(60, 70), control2: p(100, 40))
        
        path.closeSubpath()
        return path
    }
}

// MARK: - Shoulders and Triggers Overlay
private struct ShouldersAndTriggersOverlay: View {
    @ObservedObject var state: GamepadState
    
    var body: some View {
        HStack(spacing: 80) {
            // Left Shoulder & Trigger
            HStack(spacing: 12) {
                // LT
                VStack(spacing: 2) {
                    Text("LT")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(nsColor: .controlBackgroundColor))
                            .frame(width: 44, height: 26)
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.orange)
                            .frame(width: 44, height: 26 * CGFloat(state.leftTrigger.value))
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(state.leftTrigger.isPressed ? Color.orange : Color.secondary.opacity(0.3), lineWidth: 1.5)
                    )
                }
                
                // LB
                VStack(spacing: 2) {
                    Text("LB")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(state.leftShoulder.isPressed ? Color.blue : Color(nsColor: .controlBackgroundColor))
                        .frame(width: 48, height: 26)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                        )
                        .shadow(color: state.leftShoulder.isPressed ? Color.blue.opacity(0.7) : .clear, radius: 4)
                }
            }
            
            // Right Shoulder & Trigger
            HStack(spacing: 12) {
                // RB
                VStack(spacing: 2) {
                    Text("RB")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(state.rightShoulder.isPressed ? Color.blue : Color(nsColor: .controlBackgroundColor))
                        .frame(width: 48, height: 26)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                        )
                        .shadow(color: state.rightShoulder.isPressed ? Color.blue.opacity(0.7) : .clear, radius: 4)
                }
                
                // RT
                VStack(spacing: 2) {
                    Text("RT")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(nsColor: .controlBackgroundColor))
                            .frame(width: 44, height: 26)
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.orange)
                            .frame(width: 44, height: 26 * CGFloat(state.rightTrigger.value))
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(state.rightTrigger.isPressed ? Color.orange : Color.secondary.opacity(0.3), lineWidth: 1.5)
                    )
                }
            }
        }
    }
}

// MARK: - Center System Buttons
private struct CenterSystemButtons: View {
    @ObservedObject var state: GamepadState
    
    var body: some View {
        HStack(spacing: 24) {
            // Options / Select / Share
            SystemButtonIndicator(title: "SHARE", isPressed: state.buttonOptions.isPressed)
            
            // Home / PS / Xbox Guide
            Circle()
                .fill(state.buttonHome.isPressed ? Color.white : Color(nsColor: .controlBackgroundColor))
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: "house.fill")
                        .font(.system(size: 12))
                        .foregroundColor(state.buttonHome.isPressed ? Color.black : Color.secondary)
                )
                .overlay(Circle().stroke(Color.secondary.opacity(0.4), lineWidth: 1))
                .shadow(color: state.buttonHome.isPressed ? Color.white.opacity(0.8) : .clear, radius: 6)
            
            // Menu / Start
            SystemButtonIndicator(title: "MENU", isPressed: state.buttonMenu.isPressed)
        }
    }
}

private struct SystemButtonIndicator: View {
    let title: String
    let isPressed: Bool
    
    var body: some View {
        Capsule()
            .fill(isPressed ? Color.accentColor : Color(nsColor: .controlBackgroundColor))
            .frame(width: 38, height: 18)
            .overlay(
                Text(title)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(isPressed ? Color.white : Color.secondary)
            )
            .overlay(Capsule().stroke(Color.secondary.opacity(0.3), lineWidth: 1))
    }
}

// MARK: - D-Pad Module
private struct DpadModuleView: View {
    @ObservedObject var state: GamepadState
    
    var body: some View {
        ZStack {
            // D-Pad Cross Background
            CrossShape()
                .fill(Color(nsColor: .controlBackgroundColor))
                .frame(width: 90, height: 90)
                .overlay(CrossShape().stroke(Color.secondary.opacity(0.3), lineWidth: 1.5))
            
            // Up
            DpadDirectionButton(icon: "arrowtriangle.up.fill", isPressed: state.dpadUp.isPressed)
                .offset(y: -28)
            // Down
            DpadDirectionButton(icon: "arrowtriangle.down.fill", isPressed: state.dpadDown.isPressed)
                .offset(y: 28)
            // Left
            DpadDirectionButton(icon: "arrowtriangle.left.fill", isPressed: state.dpadLeft.isPressed)
                .offset(x: -28)
            // Right
            DpadDirectionButton(icon: "arrowtriangle.right.fill", isPressed: state.dpadRight.isPressed)
                .offset(x: 28)
        }
    }
}

private struct DpadDirectionButton: View {
    let icon: String
    let isPressed: Bool
    
    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 13))
            .foregroundColor(isPressed ? Color.white : Color.secondary)
            .frame(width: 24, height: 24)
            .background(isPressed ? Color.blue : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .shadow(color: isPressed ? Color.blue.opacity(0.8) : .clear, radius: 4)
    }
}

private struct CrossShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        let arm = w / 3.0
        
        path.move(to: CGPoint(x: arm, y: 0))
        path.addLine(to: CGPoint(x: arm * 2, y: 0))
        path.addLine(to: CGPoint(x: arm * 2, y: arm))
        path.addLine(to: CGPoint(x: w, y: arm))
        path.addLine(to: CGPoint(x: w, y: arm * 2))
        path.addLine(to: CGPoint(x: arm * 2, y: arm * 2))
        path.addLine(to: CGPoint(x: arm * 2, y: h))
        path.addLine(to: CGPoint(x: arm, y: h))
        path.addLine(to: CGPoint(x: arm, y: arm * 2))
        path.addLine(to: CGPoint(x: 0, y: arm * 2))
        path.addLine(to: CGPoint(x: 0, y: arm))
        path.addLine(to: CGPoint(x: arm, y: arm))
        path.closeSubpath()
        return path
    }
}

// MARK: - Action Buttons (A, B, X, Y)
private struct ActionButtonsModuleView: View {
    @ObservedObject var state: GamepadState
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.4))
                .frame(width: 100, height: 100)
            
            // Y button (Top)
            ActionButtonView(label: "Y", sublabel: "▲", color: Color.yellow, isPressed: state.buttonY.isPressed)
                .offset(y: -30)
            // A button (Bottom)
            ActionButtonView(label: "A", sublabel: "✖", color: Color.green, isPressed: state.buttonA.isPressed)
                .offset(y: 30)
            // X button (Left)
            ActionButtonView(label: "X", sublabel: "■", color: Color.blue, isPressed: state.buttonX.isPressed)
                .offset(x: -30)
            // B button (Right)
            ActionButtonView(label: "B", sublabel: "●", color: Color.red, isPressed: state.buttonB.isPressed)
                .offset(x: 30)
        }
    }
}

private struct ActionButtonView: View {
    let label: String
    let sublabel: String
    let color: Color
    let isPressed: Bool
    
    var body: some View {
        ZStack {
            Circle()
                .fill(isPressed ? color : Color(nsColor: .controlBackgroundColor))
                .frame(width: 32, height: 32)
                .overlay(
                    Circle()
                        .stroke(color.opacity(isPressed ? 1.0 : 0.6), lineWidth: isPressed ? 2.5 : 1.5)
                )
                .shadow(color: isPressed ? color.opacity(0.8) : .clear, radius: 8)
            
            VStack(spacing: -2) {
                Text(label)
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundColor(isPressed ? Color.white : color)
            }
        }
    }
}

// MARK: - Thumbstick Module
private struct ThumbstickModuleView: View {
    let title: String
    let stick: ThumbstickState
    let isPressed: Bool
    let accentColor: Color
    
    var body: some View {
        ZStack {
            // Outer Well / Base Ring
            Circle()
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.7))
                .frame(width: 76, height: 76)
                .overlay(Circle().stroke(Color.secondary.opacity(0.3), lineWidth: 1.5))
            
            // Inner Stick Top Nub
            let offsetX = CGFloat(stick.x) * 20.0
            let offsetY = -CGFloat(stick.y) * 20.0 // invert Y
            
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            isPressed ? Color.red : accentColor,
                            Color(nsColor: .controlBackgroundColor)
                        ],
                        center: .center,
                        startRadius: 2,
                        endRadius: 24
                    )
                )
                .frame(width: 44, height: 44)
                .overlay(
                    Circle()
                        .stroke(isPressed ? Color.red : Color.secondary.opacity(0.5), lineWidth: 2)
                )
                .shadow(color: (isPressed ? Color.red : accentColor).opacity(0.6), radius: 6)
                .overlay(
                    Text(title)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                )
                .offset(x: offsetX, y: offsetY)
        }
    }
}
