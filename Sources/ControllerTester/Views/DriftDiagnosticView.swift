import SwiftUI

public struct DriftDiagnosticView: View {
    @ObservedObject var state: GamepadState
    @ObservedObject var driftManager: DriftDiagnosticManager
    
    public init(state: GamepadState, driftManager: DriftDiagnosticManager) {
        self.state = state
        self.driftManager = driftManager
    }
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Deadzone & Configuration Bar
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Configured Deadzone Threshold")
                            .font(.headline)
                            .fontWeight(.bold)
                        Text("Standard game deadzones typically range between 5% and 12%")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 12) {
                        Slider(
                            value: $driftManager.deadzoneThreshold,
                            in: 0.01...0.25,
                            step: 0.01
                        )
                        .frame(width: 140)
                        
                        Text(String(format: "%.1f%%", driftManager.deadzoneThreshold * 100))
                            .font(.system(.subheadline, design: .monospaced))
                            .fontWeight(.bold)
                            .frame(width: 50, alignment: .trailing)
                    }
                    
                    Button(action: {
                        driftManager.resetDriftStats()
                    }) {
                        Label("Reset Stats", systemImage: "arrow.counterclockwise")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
                
                // Dual Thumbstick Precision Radars
                HStack(alignment: .top, spacing: 18) {
                    // Left Stick Radar
                    VStack(spacing: 10) {
                        ThumbstickRadarView(
                            title: "Left Thumbstick",
                            stick: state.leftStick,
                            isPressed: state.leftStickButton.isPressed,
                            deadzone: driftManager.deadzoneThreshold,
                            trail: driftManager.leftHistoryTrail,
                            circularityBins: driftManager.leftCircularityBins,
                            showCircularity: driftManager.isCircularityTestActive && driftManager.activeTestStick == .left,
                            color: .blue
                        )
                        
                        // Drift Health Badge
                        DriftHealthCard(
                            title: "Left Stick Centering",
                            currentOffset: driftManager.leftRestingOffset,
                            maxOffset: driftManager.leftMaxRestingDrift,
                            deadzone: driftManager.deadzoneThreshold
                        )
                    }
                    .frame(maxWidth: .infinity)
                    
                    // Right Stick Radar
                    VStack(spacing: 10) {
                        ThumbstickRadarView(
                            title: "Right Thumbstick",
                            stick: state.rightStick,
                            isPressed: state.rightStickButton.isPressed,
                            deadzone: driftManager.deadzoneThreshold,
                            trail: driftManager.rightHistoryTrail,
                            circularityBins: driftManager.rightCircularityBins,
                            showCircularity: driftManager.isCircularityTestActive && driftManager.activeTestStick == .right,
                            color: .purple
                        )
                        
                        // Drift Health Badge
                        DriftHealthCard(
                            title: "Right Stick Centering",
                            currentOffset: driftManager.rightRestingOffset,
                            maxOffset: driftManager.rightMaxRestingDrift,
                            deadzone: driftManager.deadzoneThreshold
                        )
                    }
                    .frame(maxWidth: .infinity)
                }
                
                // Circularity Benchmark Suite
                CircularityBenchmarkCard(driftManager: driftManager)
            }
            .padding(16)
        }
    }
}

private struct DriftHealthCard: View {
    let title: String
    let currentOffset: Float
    let maxOffset: Float
    let deadzone: Float
    
    var isDrifting: Bool {
        currentOffset > deadzone
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.bold)
                
                HStack(spacing: 8) {
                    Text("Resting: \(String(format: "%.1f%%", currentOffset * 100))")
                    Text("Max: \(String(format: "%.1f%%", maxOffset * 100))")
                }
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isDrifting {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text("DRIFT")
                        .fontWeight(.heavy)
                }
                .font(.caption2)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.red)
                .foregroundColor(.white)
                .clipShape(Capsule())
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("CENTERED")
                        .fontWeight(.bold)
                }
                .font(.caption2)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.green.opacity(0.2))
                .foregroundColor(.green)
                .clipShape(Capsule())
            }
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
    }
}

private struct CircularityBenchmarkCard: View {
    @ObservedObject var driftManager: DriftDiagnosticManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "circle.circle.fill")
                        .font(.title3)
                        .foregroundColor(.teal)
                    Text("Circularity & Outer Gate Benchmark")
                        .font(.headline)
                        .fontWeight(.bold)
                }
                
                Spacer()
                
                Picker("Target Stick", selection: $driftManager.activeTestStick) {
                    ForEach(StickSide.allCases) { side in
                        Text(side.rawValue).tag(side)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 260)
            }
            
            Text("Rotate the thumbstick slowly 360° around its outer rim to measure sensor circularity error and gate calibration.")
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Progress Bar & Controls
            HStack(spacing: 16) {
                Button(action: {
                    driftManager.isCircularityTestActive.toggle()
                }) {
                    Label(
                        driftManager.isCircularityTestActive ? "Stop Test" : "Start 360° Test",
                        systemImage: driftManager.isCircularityTestActive ? "stop.fill" : "play.fill"
                    )
                    .font(.caption)
                    .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .tint(driftManager.isCircularityTestActive ? .red : .teal)
                
                Button(action: {
                    driftManager.resetCircularityTest(for: driftManager.activeTestStick)
                }) {
                    Label("Clear Samples", systemImage: "trash")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                // Completion Gauge
                let completion = driftManager.completionPercentage(for: driftManager.activeTestStick)
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Perimeter Coverage: \(String(format: "%.0f%%", completion))")
                        .font(.system(.caption, design: .monospaced))
                        .fontWeight(.bold)
                    ProgressView(value: completion, total: 100)
                        .frame(width: 140)
                        .tint(.teal)
                }
            }
            
            Divider()
            
            // Error Metrics Summary
            HStack(spacing: 20) {
                let rating = driftManager.rating(for: driftManager.activeTestStick)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Average Error:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.2f%%", driftManager.averageCircularityError(for: driftManager.activeTestStick)))
                        .font(.system(.title2, design: .monospaced))
                        .fontWeight(.bold)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Max Deviation:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.2f%%", driftManager.maxCircularityError(for: driftManager.activeTestStick)))
                        .font(.system(.title2, design: .monospaced))
                        .fontWeight(.bold)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Hardware Score:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(rating.text)
                        .font(.subheadline)
                        .fontWeight(.heavy)
                        .foregroundColor(rating.color)
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
