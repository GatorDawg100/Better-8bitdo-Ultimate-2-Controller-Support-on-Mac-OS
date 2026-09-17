import SwiftUI

public struct HapticsTesterView: View {
    @ObservedObject var haptics: HapticsManager
    let hasHaptics: Bool
    
    public init(haptics: HapticsManager, hasHaptics: Bool) {
        self.haptics = haptics
        self.hasHaptics = hasHaptics
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.title3)
                        .foregroundColor(haptics.isVibrating ? .red : .accentColor)
                    Text("Controller Haptics & Rumble Motors")
                        .font(.headline)
                        .fontWeight(.bold)
                }
                
                Spacer()
                
                if haptics.isVibrating {
                    Text("VIBRATING")
                        .font(.caption2)
                        .fontWeight(.heavy)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
            }
            
            // Status bar
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(.secondary)
                Text(haptics.statusMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            // Sliders for Intensity & Sharpness
            VStack(spacing: 12) {
                HStack {
                    Text("Vibration Intensity:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 130, alignment: .leading)
                    Slider(value: $haptics.intensity, in: 0.1...1.0, step: 0.05)
                    Text(String(format: "%.0f%%", haptics.intensity * 100.0))
                        .font(.system(.caption, design: .monospaced))
                        .frame(width: 45, alignment: .trailing)
                }
                
                HStack {
                    Text("Sharpness (Frequency):")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 130, alignment: .leading)
                    Slider(value: $haptics.sharpness, in: 0.0...1.0, step: 0.05)
                    Text(String(format: "%.0f%%", haptics.sharpness * 100.0))
                        .font(.system(.caption, design: .monospaced))
                        .frame(width: 45, alignment: .trailing)
                }
            }
            
            Divider()
            
            // Preset Patterns
            VStack(alignment: .leading, spacing: 8) {
                Text("Haptic Test Patterns")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], spacing: 10) {
                    ForEach(HapticPresetPattern.allCases) { preset in
                        Button(action: {
                            haptics.playPreset(preset)
                        }) {
                            Label(preset.rawValue, systemImage: preset.icon)
                                .font(.caption)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(preset == .continuous ? .purple : .blue)
                    }
                }
            }
            
            // Emergency Stop / Continuous toggle
            HStack(spacing: 12) {
                Button(action: {
                    haptics.startContinuousRumble()
                }) {
                    Label("Start Continuous Rumble", systemImage: "play.circle.fill")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                
                Button(action: {
                    haptics.stopHaptics()
                }) {
                    Label("Emergency Stop Haptics", systemImage: "stop.circle.fill")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .tint(.red)
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
