import SwiftUI

public struct TriggerBarView: View {
    let title: String
    let subtitle: String
    let value: Float
    let isPressed: Bool
    let pressCount: Int
    let color: Color
    
    public init(
        title: String,
        subtitle: String,
        value: Float,
        isPressed: Bool,
        pressCount: Int = 0,
        color: Color = .purple
    ) {
        self.title = title
        self.subtitle = subtitle
        self.value = value
        self.isPressed = isPressed
        self.pressCount = pressCount
        self.color = color
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.bold)
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%.1f%%", value * 100.0))
                        .font(.system(.title3, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundColor(value > 0 ? color : .secondary)
                    
                    Text("Value: \(String(format: "%.3f", value))")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
            
            // Analog Bar Gauge
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track background
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(nsColor: .controlBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        )
                    
                    // Fill bar
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.6), color],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(value))))
                        .animation(.interactiveSpring(response: 0.15, dampingFraction: 0.8), value: value)
                    
                    // Hair-trigger threshold line (typical 0.10)
                    Rectangle()
                        .fill(Color.white.opacity(0.4))
                        .frame(width: 2, height: geo.size.height)
                        .offset(x: geo.size.width * 0.1)
                }
            }
            .frame(height: 22)
            
            // Bottom stats
            HStack {
                HStack(spacing: 4) {
                    Circle()
                        .fill(isPressed ? Color.green : Color.secondary.opacity(0.4))
                        .frame(width: 8, height: 8)
                    Text(isPressed ? "Active" : "Neutral")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if pressCount > 0 {
                    Text("Actuations: \(pressCount)")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(14)
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
