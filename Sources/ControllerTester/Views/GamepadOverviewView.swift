import SwiftUI

public struct GamepadOverviewView: View {
    @ObservedObject var state: GamepadState
    @ObservedObject var hapticsManager: HapticsManager
    
    public init(state: GamepadState, hapticsManager: HapticsManager) {
        self.state = state
        self.hapticsManager = hapticsManager
    }
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Interactive Controller Canvas
                GamepadCanvasView(
                    state: state,
                    hapticsManager: hapticsManager
                )
                .frame(height: 380)
                .padding(.horizontal)
                
                // Quick Telemetry Overview Cards
                HStack(spacing: 14) {
                    // Left Stick Summary
                    StickSummaryCard(
                        title: "Left Stick",
                        x: state.leftStick.x,
                        y: state.leftStick.y,
                        isPressed: state.leftStickButton.isPressed,
                        accent: .blue
                    )
                    
                    // Triggers Summary
                    TriggersSummaryCard(
                        leftValue: state.leftTrigger.value,
                        rightValue: state.rightTrigger.value
                    )
                    
                    // Right Stick Summary
                    StickSummaryCard(
                        title: "Right Stick",
                        x: state.rightStick.x,
                        y: state.rightStick.y,
                        isPressed: state.rightStickButton.isPressed,
                        accent: .purple
                    )
                    
                    // Polling Rate Summary
                    PollingRateCard(
                        hz: state.pollingRateHz,
                        totalEvents: state.totalEventsCount
                    )
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
    }
}

private struct StickSummaryCard: View {
    let title: String
    let x: Float
    let y: Float
    let isPressed: Bool
    let accent: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.caption)
                    .fontWeight(.bold)
                Spacer()
                if isPressed {
                    Circle().fill(Color.red).frame(width: 6, height: 6)
                }
            }
            
            HStack {
                Text("X: \(String(format: "%+.2f", x))")
                Spacer()
                Text("Y: \(String(format: "%+.2f", y))")
            }
            .font(.system(.caption, design: .monospaced))
            .foregroundColor(.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
    }
}

private struct TriggersSummaryCard: View {
    let leftValue: Float
    let rightValue: Float
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Triggers")
                .font(.caption)
                .fontWeight(.bold)
            
            HStack {
                Text("LT: \(String(format: "%.0f%%", leftValue * 100))")
                Spacer()
                Text("RT: \(String(format: "%.0f%%", rightValue * 100))")
            }
            .font(.system(.caption, design: .monospaced))
            .foregroundColor(.orange)
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
    }
}

private struct PollingRateCard: View {
    let hz: Double
    let totalEvents: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Polling Rate")
                .font(.caption)
                .fontWeight(.bold)
            
            HStack {
                Text(String(format: "%.0f Hz", hz))
                    .foregroundColor(hz > 100 ? .green : .accentColor)
                    .fontWeight(.bold)
                Spacer()
                Text("\(totalEvents) evt")
                    .foregroundColor(.secondary)
            }
            .font(.system(.caption, design: .monospaced))
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
    }
}
