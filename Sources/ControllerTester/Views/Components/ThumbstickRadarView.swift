import SwiftUI

public struct ThumbstickRadarView: View {
    let title: String
    let stick: ThumbstickState
    let isPressed: Bool
    let deadzone: Float
    let trail: [CGPoint]
    let circularityBins: [CircularityPoint]
    let showCircularity: Bool
    let color: Color
    
    public init(
        title: String,
        stick: ThumbstickState,
        isPressed: Bool,
        deadzone: Float = 0.05,
        trail: [CGPoint] = [],
        circularityBins: [CircularityPoint] = [],
        showCircularity: Bool = false,
        color: Color = .blue
    ) {
        self.title = title
        self.stick = stick
        self.isPressed = isPressed
        self.deadzone = deadzone
        self.trail = trail
        self.circularityBins = circularityBins
        self.showCircularity = showCircularity
        self.color = color
    }
    
    public var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text(title)
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
                if isPressed {
                    Text("CLICKED (L3/R3)")
                        .font(.caption2)
                        .fontWeight(.heavy)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
            }
            
            // Circular Radar Display
            GeometryReader { geo in
                let size = min(geo.size.width, geo.size.height)
                let radius = size / 2.0
                let center = CGPoint(x: geo.size.width / 2.0, y: geo.size.height / 2.0)
                
                ZStack {
                    // Outer background ring
                    Circle()
                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                        .overlay(Circle().stroke(Color.secondary.opacity(0.3), lineWidth: 1.5))
                    
                    // Concentric grid rings (25%, 50%, 75%, 100%)
                    ForEach([0.25, 0.5, 0.75, 1.0], id: \.self) { fraction in
                        Circle()
                            .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
                            .frame(width: size * fraction, height: size * fraction)
                    }
                    
                    // Crosshairs
                    Path { path in
                        path.move(to: CGPoint(x: center.x - radius, y: center.y))
                        path.addLine(to: CGPoint(x: center.x + radius, y: center.y))
                        path.move(to: CGPoint(x: center.x, y: center.y - radius))
                        path.addLine(to: CGPoint(x: center.x, y: center.y + radius))
                    }
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    
                    // Deadzone threshold ring
                    Circle()
                        .stroke(Color.orange.opacity(0.7), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                        .frame(width: size * CGFloat(deadzone), height: size * CGFloat(deadzone))
                    
                    // Circularity outer envelope if testing
                    if showCircularity && !circularityBins.isEmpty {
                        Path { path in
                            var first = true
                            for bin in circularityBins {
                                let dist = min(1.2, max(0.0, CGFloat(bin.maxDistance)))
                                let angleRad = bin.angleDeg * .pi / 180.0
                                let pt = CGPoint(
                                    x: center.x + cos(angleRad) * radius * dist,
                                    y: center.y - sin(angleRad) * radius * dist
                                )
                                if first {
                                    path.move(to: pt)
                                    first = false
                                } else {
                                    path.addLine(to: pt)
                                }
                            }
                            path.closeSubpath()
                        }
                        .stroke(Color.teal, style: StrokeStyle(lineWidth: 2, lineJoin: .round))
                    }
                    
                    // Recent position trail
                    if !trail.isEmpty {
                        Path { path in
                            for (index, point) in trail.enumerated() {
                                let pt = CGPoint(
                                    x: center.x + point.x * radius,
                                    y: center.y - point.y * radius // invert Y for screen coords
                                )
                                if index == 0 {
                                    path.move(to: pt)
                                } else {
                                    path.addLine(to: pt)
                                }
                            }
                        }
                        .stroke(color.opacity(0.35), lineWidth: 2)
                    }
                    
                    // Vector line to current stick point
                    let stickPt = CGPoint(
                        x: center.x + CGFloat(stick.x) * radius,
                        y: center.y - CGFloat(stick.y) * radius
                    )
                    
                    Path { path in
                        path.move(to: center)
                        path.addLine(to: stickPt)
                    }
                    .stroke(color.opacity(0.8), lineWidth: 2)
                    
                    // Current position thumbstick knob
                    Circle()
                        .fill(isPressed ? Color.red : color)
                        .frame(width: 24, height: 24)
                        .shadow(color: (isPressed ? Color.red : color).opacity(0.6), radius: 6)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                        )
                        .position(stickPt)
                }
            }
            .aspectRatio(1.0, contentMode: .fit)
            
            // Coordinate Readouts
            HStack(spacing: 12) {
                CoordBadge(label: "X", value: String(format: "%+.3f", stick.x))
                CoordBadge(label: "Y", value: String(format: "%+.3f", stick.y))
                CoordBadge(label: "Mag", value: String(format: "%.3f", stick.magnitude))
                CoordBadge(label: "θ", value: String(format: "%.0f°", stick.angleDegrees))
            }
            .font(.system(.caption, design: .monospaced))
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

private struct CoordBadge: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
