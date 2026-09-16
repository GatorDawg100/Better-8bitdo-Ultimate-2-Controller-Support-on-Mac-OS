import SwiftUI

public struct MotionSensorDetailView: View {
    @ObservedObject var state: GamepadState
    var onRecalibrate: (() -> Void)? = nil
    
    public init(state: GamepadState, onRecalibrate: (() -> Void)? = nil) {
        self.state = state
        self.onRecalibrate = onRecalibrate
    }
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let advisory = state.hardwareAdvisory {
                    HardwareAdvisoryView(
                        title: "8BitDo Hardware Integration Status",
                        message: advisory
                    )
                }
                
                Motion3DView(motion: state.motion, onRecalibrate: onRecalibrate)
                
                // Acceleration & Force Breakdown
                VStack(alignment: .leading, spacing: 14) {
                    Text("Linear & User Acceleration")
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    HStack(spacing: 16) {
                        AccelerationMeter(label: "User Accel X", value: state.motion.userAccelX, color: .red)
                        AccelerationMeter(label: "User Accel Y", value: state.motion.userAccelY, color: .green)
                        AccelerationMeter(label: "User Accel Z", value: state.motion.userAccelZ, color: .blue)
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
            .padding(16)
        }
    }
}

private struct AccelerationMeter: View {
    let label: String
    let value: Double
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Text(String(format: "%+.3f g", value))
                .font(.system(.subheadline, design: .monospaced))
                .fontWeight(.bold)
            
            // Bi-directional meter (-2g to +2g)
            GeometryReader { geo in
                let w = geo.size.width
                let mid = w / 2.0
                let clamped = min(2.0, max(-2.0, value))
                let barW = (abs(clamped) / 2.0) * mid
                let startX = clamped >= 0 ? mid : mid - barW
                
                ZStack(alignment: .leading) {
                    Rectangle().fill(Color(nsColor: .controlBackgroundColor))
                    Rectangle().fill(Color.secondary.opacity(0.3)).frame(width: 1).position(x: mid, y: geo.size.height / 2)
                    
                    Rectangle()
                        .fill(color)
                        .frame(width: barW, height: geo.size.height)
                        .offset(x: startX)
                }
            }
            .frame(height: 10)
            .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity)
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
