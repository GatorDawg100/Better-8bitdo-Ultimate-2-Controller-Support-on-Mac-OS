import SwiftUI

public struct ButtonMatrixView: View {
    @ObservedObject var state: GamepadState
    
    public init(state: GamepadState) {
        self.state = state
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Button Actuation & Switch Health")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
                Button(action: {
                    state.resetCounters()
                }) {
                    Label("Reset Counters", systemImage: "arrow.counterclockwise")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
            }
            
            // Grid of buttons
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140, maximum: 180), spacing: 12)], spacing: 12) {
                ButtonItemCard(name: "Button A", symbol: "a.circle.fill", btnState: state.buttonA, accent: .green)
                ButtonItemCard(name: "Button B", symbol: "b.circle.fill", btnState: state.buttonB, accent: .red)
                ButtonItemCard(name: "Button X", symbol: "x.circle.fill", btnState: state.buttonX, accent: .blue)
                ButtonItemCard(name: "Button Y", symbol: "y.circle.fill", btnState: state.buttonY, accent: .yellow)
                
                ButtonItemCard(name: "Left Bumper (LB)", symbol: "l1.rectangle.roundedbottom", btnState: state.leftShoulder, accent: .purple)
                ButtonItemCard(name: "Right Bumper (RB)", symbol: "r1.rectangle.roundedbottom", btnState: state.rightShoulder, accent: .purple)
                
                ButtonItemCard(name: "Left Stick (L3)", symbol: "l.joystick.press.down", btnState: state.leftStickButton, accent: .blue)
                ButtonItemCard(name: "Right Stick (R3)", symbol: "r.joystick.press.down", btnState: state.rightStickButton, accent: .purple)
                
                ButtonItemCard(name: "D-Pad Up", symbol: "arrow.up", btnState: state.dpadUp, accent: .cyan)
                ButtonItemCard(name: "D-Pad Down", symbol: "arrow.down", btnState: state.dpadDown, accent: .cyan)
                ButtonItemCard(name: "D-Pad Left", symbol: "arrow.left", btnState: state.dpadLeft, accent: .cyan)
                ButtonItemCard(name: "D-Pad Right", symbol: "arrow.right", btnState: state.dpadRight, accent: .cyan)
                
                ButtonItemCard(name: "Menu / Start", symbol: "line.3.horizontal", btnState: state.buttonMenu, accent: .orange)
                ButtonItemCard(name: "Options / Select", symbol: "square.and.arrow.up", btnState: state.buttonOptions, accent: .orange)
                ButtonItemCard(name: "Home / Guide", symbol: "house.fill", btnState: state.buttonHome, accent: .white)
            }
            
            // Dynamic extra buttons from physical profile (e.g. 8BitDo M1, M2, L4, R4)
            if !state.dynamicButtons.isEmpty {
                Divider()
                
                HStack {
                    Text("Controller-Specific / Back Paddle Buttons")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Spacer()
                    Text("\(state.dynamicButtons.count) Detected")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.2))
                        .foregroundColor(.orange)
                        .clipShape(Capsule())
                }
                
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140, maximum: 180), spacing: 12)], spacing: 12) {
                    ForEach(Array(state.dynamicButtons.keys.sorted()), id: \.self) { key in
                        if let btnState = state.dynamicButtons[key] {
                            let meta = state.dynamicButtonMetadata[key]
                            ButtonItemCard(
                                name: meta?.name ?? key,
                                symbol: meta?.symbol ?? "circle.grid.2x1.fill",
                                btnState: btnState,
                                accent: .orange
                            )
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.7))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

private struct ButtonItemCard: View {
    let name: String
    let symbol: String
    let btnState: ButtonInputState
    let accent: Color
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 16))
                .foregroundColor(btnState.isPressed ? .white : accent)
                .frame(width: 32, height: 32)
                .background(btnState.isPressed ? accent : Color.secondary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(color: btnState.isPressed ? accent.opacity(0.8) : .clear, radius: 4)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                
                HStack(spacing: 6) {
                    Text("\(btnState.pressCount) hits")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                    
                    if btnState.lastPressDurationMs > 0 {
                        Text(String(format: "%.0fms", btnState.lastPressDurationMs))
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.accentColor)
                    }
                }
            }
            
            Spacer(minLength: 0)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(btnState.isPressed ? accent : Color.clear, lineWidth: 1.5)
                )
        )
    }
}
