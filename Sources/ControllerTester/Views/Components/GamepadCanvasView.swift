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
                    // Back Paddles: Left Grip Paddle and Right Grip Paddle
                    BackPaddleWing(
                        title: "M1",
                        isPressed: state.paddle1.isPressed,
                        isLeft: true
                    )
                    .offset(x: -250, y: 130)
                    
                    BackPaddleWing(
                        title: "M2",
                        isPressed: state.paddle2.isPressed,
                        isLeft: false
                    )
                    .offset(x: 250, y: 130)
                    
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
                    
                    // Top Shoulders & Triggers (including L4 and R4)
                    ShouldersAndTriggersOverlay(state: state)
                        .offset(y: -140)
                    
                    // Center System Buttons (Menu, Options/Share, Home)
                    CenterSystemButtons(state: state)
                        .offset(y: -40)
                    
                    // Left Thumbstick (LS) - Upper-Left position (8BitDo / Xbox Layout)
                    ThumbstickModuleView(
                        title: "LS",
                        stick: state.leftStick,
                        isPressed: state.leftStickButton.isPressed,
                        accentColor: .blue
                    )
                    .offset(x: -140, y: -25)
                    
                    // D-Pad - Lower-Left position (8BitDo / Xbox Layout)
                    DpadModuleView(state: state)
                        .offset(x: -75, y: 45)
                    
                    // Right Action Buttons (A, B, X, Y) - Upper-Right position
                    ActionButtonsModuleView(state: state)
                        .offset(x: 140, y: -25)
                    
                    // Right Thumbstick (RS) - Lower-Right position
                    ThumbstickModuleView(
                        title: "RS",
                        stick: state.rightStick,
                        isPressed: state.rightStickButton.isPressed,
                        accentColor: .purple
                    )
                    .offset(x: 75, y: 45)
                }
                .frame(width: 580, height: 380)
                .scaleEffect(scale)
                .rotation3DEffect(
                    .degrees(state.motion.hasMotion ? (state.motion.pitch * 180.0 / .pi) * 0.3 : 0),
                    axis: (x: 1, y: 0, z: 0)
                )
                .rotation3DEffect(
                    .degrees(state.motion.hasMotion ? (-state.motion.roll * 180.0 / .pi) * 0.3 : 0),
                    axis: (x: 0, y: 1, z: 0)
                )
                .rotation3DEffect(
                    .degrees(state.motion.hasMotion ? (-state.motion.yaw * 180.0 / .pi) * 0.15 : 0),
                    axis: (x: 0, y: 0, z: 1)
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

// MARK: - Back Paddle Wing (M1 & M2)
private struct BackPaddleWing: View {
    let title: String
    let isPressed: Bool
    let isLeft: Bool
    
    var body: some View {
        HStack(spacing: 6) {
            if !isLeft {
                Text(title)
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundColor(isPressed ? Color.green : Color.secondary)
            }
            
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            isPressed ? Color.green : Color(nsColor: .controlBackgroundColor),
                            isPressed ? Color.green.opacity(0.8) : Color(nsColor: .windowBackgroundColor)
                        ],
                        startPoint: isLeft ? .leading : .trailing,
                        endPoint: isLeft ? .trailing : .leading
                    )
                )
                .frame(width: 20, height: 75)
                .overlay(
                    Capsule()
                        .stroke(isPressed ? Color.green : Color.secondary.opacity(0.4), lineWidth: isPressed ? 2 : 1)
                )
                .shadow(color: isPressed ? Color.green.opacity(0.8) : Color.clear, radius: 8)
            
            if isLeft {
                Text(title)
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundColor(isPressed ? Color.green : Color.secondary)
            }
        }
    }
}

// MARK: - Controller Chassis Vector Path
private struct ControllerChassisPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
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
        HStack(spacing: 50) {
            // Left Group: LT (Trigger), LB (Bumper), L4 (Extra Bumper)
            HStack(spacing: 8) {
                // LT
                VStack(spacing: 2) {
                    Text("LT")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(nsColor: .controlBackgroundColor))
                            .frame(width: 40, height: 26)
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.orange)
                            .frame(width: 40, height: 26 * CGFloat(state.leftTrigger.value))
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(state.leftTrigger.isPressed ? Color.orange : Color.secondary.opacity(0.3), lineWidth: 1.5)
                    )
                }
                
                // LB
                VStack(spacing: 2) {
                    Text("LB")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(state.leftShoulder.isPressed ? Color.blue : Color(nsColor: .controlBackgroundColor))
                        .frame(width: 42, height: 26)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(state.leftShoulder.isPressed ? Color.blue : Color.secondary.opacity(0.3), lineWidth: 1)
                        )
                        .shadow(color: state.leftShoulder.isPressed ? Color.blue.opacity(0.7) : .clear, radius: 4)
                }
                
                // L4 (Extra Bumper Button)
                VStack(spacing: 2) {
                    Text("L4")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundColor(state.buttonL4.isPressed ? Color.cyan : Color.secondary)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(state.buttonL4.isPressed ? Color.cyan : Color(nsColor: .controlBackgroundColor))
                        .frame(width: 34, height: 26)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(state.buttonL4.isPressed ? Color.cyan : Color.secondary.opacity(0.3), lineWidth: 1.5)
                        )
                        .shadow(color: state.buttonL4.isPressed ? Color.cyan.opacity(0.8) : .clear, radius: 6)
                }
            }
            
            // Right Group: R4 (Extra Bumper), RB (Bumper), RT (Trigger)
            HStack(spacing: 8) {
                // R4 (Extra Bumper Button)
                VStack(spacing: 2) {
                    Text("R4")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundColor(state.buttonR4.isPressed ? Color.cyan : Color.secondary)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(state.buttonR4.isPressed ? Color.cyan : Color(nsColor: .controlBackgroundColor))
                        .frame(width: 34, height: 26)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(state.buttonR4.isPressed ? Color.cyan : Color.secondary.opacity(0.3), lineWidth: 1.5)
                        )
                        .shadow(color: state.buttonR4.isPressed ? Color.cyan.opacity(0.8) : .clear, radius: 6)
                }
                
                // RB
                VStack(spacing: 2) {
                    Text("RB")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(state.rightShoulder.isPressed ? Color.blue : Color(nsColor: .controlBackgroundColor))
                        .frame(width: 42, height: 26)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(state.rightShoulder.isPressed ? Color.blue : Color.secondary.opacity(0.3), lineWidth: 1)
                        )
                        .shadow(color: state.rightShoulder.isPressed ? Color.blue.opacity(0.7) : .clear, radius: 4)
                }
                
                // RT
                VStack(spacing: 2) {
                    Text("RT")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(nsColor: .controlBackgroundColor))
                            .frame(width: 40, height: 26)
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.orange)
                            .frame(width: 40, height: 26 * CGFloat(state.rightTrigger.value))
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
            SystemButtonIndicator(title: "SELECT", isPressed: state.buttonOptions.isPressed)
            
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
            SystemButtonIndicator(title: "START", isPressed: state.buttonMenu.isPressed)
        }
    }
}

private struct SystemButtonIndicator: View {
    let title: String
    let isPressed: Bool
    
    var body: some View {
        Capsule()
            .fill(isPressed ? Color.accentColor : Color(nsColor: .controlBackgroundColor))
            .frame(width: 44, height: 18)
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
                .frame(width: 86, height: 86)
                .overlay(CrossShape().stroke(Color.secondary.opacity(0.3), lineWidth: 1.5))
            
            // Up
            DpadDirectionButton(icon: "arrowtriangle.up.fill", isPressed: state.dpadUp.isPressed)
                .offset(y: -26)
            // Down
            DpadDirectionButton(icon: "arrowtriangle.down.fill", isPressed: state.dpadDown.isPressed)
                .offset(y: 26)
            // Left
            DpadDirectionButton(icon: "arrowtriangle.left.fill", isPressed: state.dpadLeft.isPressed)
                .offset(x: -26)
            // Right
            DpadDirectionButton(icon: "arrowtriangle.right.fill", isPressed: state.dpadRight.isPressed)
                .offset(x: 26)
        }
    }
}

private struct DpadDirectionButton: View {
    let icon: String
    let isPressed: Bool
    
    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 12))
            .foregroundColor(isPressed ? Color.white : Color.secondary)
            .frame(width: 22, height: 22)
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
                .frame(width: 96, height: 96)
            
            // Y button (Top)
            ActionButtonView(label: "Y", sublabel: "▲", color: Color.yellow, isPressed: state.buttonY.isPressed)
                .offset(y: -28)
            // A button (Bottom)
            ActionButtonView(label: "A", sublabel: "✖", color: Color.green, isPressed: state.buttonA.isPressed)
                .offset(y: 28)
            // X button (Left)
            ActionButtonView(label: "X", sublabel: "■", color: Color.blue, isPressed: state.buttonX.isPressed)
                .offset(x: -28)
            // B button (Right)
            ActionButtonView(label: "B", sublabel: "●", color: Color.red, isPressed: state.buttonB.isPressed)
                .offset(x: 28)
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
                .frame(width: 30, height: 30)
                .overlay(
                    Circle()
                        .stroke(color.opacity(isPressed ? 1.0 : 0.6), lineWidth: isPressed ? 2.5 : 1.5)
                )
                .shadow(color: isPressed ? color.opacity(0.8) : .clear, radius: 8)
            
            Text(label)
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundColor(isPressed ? Color.white : color)
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
            let offsetX = CGFloat(stick.x) * 18.0
            let offsetY = -CGFloat(stick.y) * 18.0 // invert Y
            
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
