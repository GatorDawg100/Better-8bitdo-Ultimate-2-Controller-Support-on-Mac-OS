import SwiftUI

public struct Motion3DView: View {
    let motion: ControllerMotionState
    var onRecalibrate: (() -> Void)? = nil
    
    public init(motion: ControllerMotionState, onRecalibrate: (() -> Void)? = nil) {
        self.motion = motion
        self.onRecalibrate = onRecalibrate
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            // Header / Availability
            HStack {
                Text("Controller IMU & Motion Sensors")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
                
                if let onRecalibrate = onRecalibrate {
                    Button(action: onRecalibrate) {
                        Label("Zero Heading / Calibrate", systemImage: "arrow.counterclockwise")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                }
                
                HStack(spacing: 6) {
                    Circle()
                        .fill(motion.hasMotion ? Color.green : Color.secondary)
                        .frame(width: 8, height: 8)
                    Text(motion.hasMotion ? "Sensor Streaming (Active)" : "Sensor Inactive / Unsupported")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            HStack(spacing: 20) {
                // 3D Horizon / Attitude Sphere
                VStack(spacing: 8) {
                    Text("Attitude Horizon")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.blue.opacity(0.6), Color.brown.opacity(0.6)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 150, height: 150)
                            .overlay(Circle().stroke(Color.white.opacity(0.4), lineWidth: 2))
                            // Rotate by roll and offset by pitch
                            .rotationEffect(.degrees(motion.roll * 180.0 / .pi))
                            .offset(y: CGFloat(motion.pitch * 30.0))
                            .clipShape(Circle())
                        
                        // Crosshair horizon reticle
                        Path { path in
                            path.move(to: CGPoint(x: 20, y: 75))
                            path.addLine(to: CGPoint(x: 60, y: 75))
                            path.move(to: CGPoint(x: 90, y: 75))
                            path.addLine(to: CGPoint(x: 130, y: 75))
                            path.addEllipse(in: CGRect(x: 72, y: 72, width: 6, height: 6))
                        }
                        .stroke(Color.yellow, lineWidth: 2)
                        .frame(width: 150, height: 150)
                    }
                    .frame(width: 150, height: 150)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.secondary.opacity(0.3), lineWidth: 2))
                    
                    VStack(spacing: 3) {
                        Text("Roll: \(String(format: "%+.1f°", motion.roll * 180.0 / .pi))  |  Pitch: \(String(format: "%+.1f°", motion.pitch * 180.0 / .pi))")
                        Text("Heading / Yaw: \(String(format: "%+.1f°", motion.yaw * 180.0 / .pi))")
                    }
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                )
                
                // Rotation Rate & Accelerometer Readouts
                VStack(spacing: 12) {
                    SensorTelemetryGroup(
                        title: "Gyroscope (Rotation Rate)",
                        icon: "gyroscope",
                        items: [
                            ("X (Pitch Rate)", String(format: "%+.1f°/s (%+.2f rad/s)", motion.rotationRateX * 180.0 / .pi, motion.rotationRateX)),
                            ("Y (Roll Rate)", String(format: "%+.1f°/s (%+.2f rad/s)", motion.rotationRateY * 180.0 / .pi, motion.rotationRateY)),
                            ("Z (Yaw Rate)", String(format: "%+.1f°/s (%+.2f rad/s)", motion.rotationRateZ * 180.0 / .pi, motion.rotationRateZ))
                        ]
                    )
                    
                    SensorTelemetryGroup(
                        title: "Gravity Vector (g)",
                        icon: "arrow.down.to.line.compact",
                        items: [
                            ("X", String(format: "%+.2f g", motion.gravityX)),
                            ("Y", String(format: "%+.2f g", motion.gravityY)),
                            ("Z", String(format: "%+.2f g", motion.gravityZ))
                        ]
                    )
                }
                .frame(maxWidth: .infinity)
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

private struct SensorTelemetryGroup: View {
    let title: String
    let icon: String
    let items: [(String, String)]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundColor(.accentColor)
                Text(title)
                    .font(.caption)
                    .fontWeight(.bold)
            }
            
            HStack(spacing: 8) {
                ForEach(items, id: \.0) { item in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.0)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(item.1)
                            .font(.system(.caption, design: .monospaced))
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(6)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
        }
    }
}
