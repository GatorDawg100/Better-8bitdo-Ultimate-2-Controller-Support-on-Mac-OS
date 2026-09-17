import SwiftUI

public struct Motion3DView: View {
    let motion: ControllerMotionState
    var onRecalibrate: (() -> Void)? = nil
    
    public init(motion: ControllerMotionState, onRecalibrate: (() -> Void)? = nil) {
        self.motion = motion
        self.onRecalibrate = onRecalibrate
    }
    
    private var pitchDeg: Double {
        motion.pitch * 180.0 / .pi
    }
    
    private var rollDeg: Double {
        motion.roll * 180.0 / .pi
    }
    
    private var yawDeg: Double {
        motion.yaw * 180.0 / .pi
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("Controller IMU & 6-Axis Motion")
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
                    Text(motion.hasMotion ? "IMU Active (Streaming)" : "Sensor Inactive")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            HStack(spacing: 16) {
                // 1. Aviation Artificial Horizon Indicator
                VStack(spacing: 8) {
                    Text("Attitude Horizon")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    ArtificialHorizonGauge(pitchDeg: pitchDeg, rollDeg: rollDeg)
                        .frame(width: 150, height: 150)
                    
                    HStack(spacing: 8) {
                        Text("Roll: \(String(format: "%+.1f°", rollDeg))")
                        Text("•")
                        Text("Pitch: \(String(format: "%+.1f°", pitchDeg))")
                    }
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                )
                
                // 2. Interactive 3D Perspective Orientation Model
                VStack(spacing: 8) {
                    Text("3D Orientation Preview")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(nsColor: .windowBackgroundColor).opacity(0.5))
                        
                        // 3D Perspective Controller Card
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 120, height: 80)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.white.opacity(0.5), lineWidth: 1.5)
                                )
                                .shadow(color: Color.blue.opacity(0.4), radius: 10, x: 0, y: 5)
                            
                            VStack(spacing: 4) {
                                Image(systemName: "gamecontroller.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.white)
                                Text("8BitDo IMU")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                        // Apply 3D spatial rotation based on pitch, roll, and yaw
                        .rotation3DEffect(.degrees(pitchDeg), axis: (x: 1, y: 0, z: 0))
                        .rotation3DEffect(.degrees(-rollDeg), axis: (x: 0, y: 1, z: 0))
                        .rotation3DEffect(.degrees(-yawDeg), axis: (x: 0, y: 0, z: 1))
                    }
                    .frame(height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    Text("Yaw / Heading: \(String(format: "%+.1f°", yawDeg))")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                )
            }
            
            // Sensor Telemetry Cards
            HStack(spacing: 16) {
                SensorTelemetryGroup(
                    title: "Gyroscope (Rotation Rate)",
                    icon: "gyroscope",
                    items: [
                        ("Pitch Rate", String(format: "%+.1f°/s", motion.rotationRateX * 180.0 / .pi)),
                        ("Roll Rate", String(format: "%+.1f°/s", motion.rotationRateY * 180.0 / .pi)),
                        ("Yaw Rate", String(format: "%+.1f°/s", motion.rotationRateZ * 180.0 / .pi))
                    ]
                )
                
                SensorTelemetryGroup(
                    title: "Gravity Vector (g)",
                    icon: "arrow.down.to.line.compact",
                    items: [
                        ("Grav X", String(format: "%+.2f g", motion.gravityX)),
                        ("Grav Y", String(format: "%+.2f g", motion.gravityY)),
                        ("Grav Z", String(format: "%+.2f g", motion.gravityZ))
                    ]
                )
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

// MARK: - Aviation Artificial Horizon Gauge
private struct ArtificialHorizonGauge: View {
    let pitchDeg: Double
    let rollDeg: Double
    
    var body: some View {
        ZStack {
            // Inner Pitch/Roll Disk (300x300 clipped to 150x150)
            ZStack {
                // Sky (Top Half)
                Rectangle()
                    .fill(Color(red: 0.2, green: 0.55, blue: 0.85))
                    .frame(width: 300, height: 150)
                    .offset(y: -75)
                
                // Ground (Bottom Half)
                Rectangle()
                    .fill(Color(red: 0.45, green: 0.32, blue: 0.20))
                    .frame(width: 300, height: 150)
                    .offset(y: 75)
                
                // Horizon Line
                Rectangle()
                    .fill(Color.white)
                    .frame(width: 300, height: 2)
                
                // Pitch Ladder lines (every 10 degrees, 1° ≈ 1.2 points)
                VStack(spacing: 24) {
                    PitchLadderBar(angle: "+20", width: 44)
                    PitchLadderBar(angle: "+10", width: 30)
                    Spacer().frame(height: 2)
                    PitchLadderBar(angle: "-10", width: 30)
                    PitchLadderBar(angle: "-20", width: 44)
                }
            }
            .frame(width: 300, height: 300)
            // Pitch translation (clamped)
            .offset(y: CGFloat(min(50, max(-50, pitchDeg * 1.5))))
            // Roll rotation
            .rotationEffect(.degrees(-rollDeg))
            .frame(width: 150, height: 150)
            .clipShape(Circle())
            
            // Fixed Outer Bezel
            Circle()
                .stroke(Color.secondary.opacity(0.4), lineWidth: 2)
                .frame(width: 150, height: 150)
            
            // Fixed Aircraft Center Wings & Reticle (Yellow)
            HStack(spacing: 24) {
                // Left Wing
                Rectangle()
                    .fill(Color.yellow)
                    .frame(width: 36, height: 3)
                
                // Center pip
                Circle()
                    .fill(Color.yellow)
                    .frame(width: 6, height: 6)
                
                // Right Wing
                Rectangle()
                    .fill(Color.yellow)
                    .frame(width: 36, height: 3)
            }
            
            // Top Roll Pointer
            Image(systemName: "arrowtriangle.down.fill")
                .font(.system(size: 8))
                .foregroundColor(.yellow)
                .offset(y: -68)
        }
        .frame(width: 150, height: 150)
    }
}

private struct PitchLadderBar: View {
    let angle: String
    let width: CGFloat
    
    var body: some View {
        HStack(spacing: 4) {
            Text(angle)
                .font(.system(size: 7, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.8))
            Rectangle()
                .fill(Color.white.opacity(0.8))
                .frame(width: width, height: 1.5)
            Text(angle)
                .font(.system(size: 7, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.8))
        }
    }
}

// MARK: - Sensor Telemetry Group
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
                            .fontWeight(.bold)
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
