import Foundation
import SwiftUI

public struct CircularityPoint: Identifiable, Sendable {
    public let id: Int // Bin index 0..<numBins
    public let angleDeg: Double
    public var maxDistance: Float
    public var sampleX: Float
    public var sampleY: Float
    
    public var errorPercentage: Float {
        abs(maxDistance - 1.0) * 100.0
    }
}

public enum StickSide: String, CaseIterable, Identifiable, Sendable {
    case left = "Left Thumbstick"
    case right = "Right Thumbstick"
    
    public var id: String { rawValue }
}

@MainActor
public final class DriftDiagnosticManager: ObservableObject {
    public static let numBins = 72 // 5-degree increments
    
    // Configurable deadzone threshold (0.0 to 0.3)
    @Published public var deadzoneThreshold: Float = 0.05
    
    // Left stick metrics
    @Published public var leftRestingOffset: Float = 0.0
    @Published public var leftMaxRestingDrift: Float = 0.0
    @Published public var leftHistoryTrail: [CGPoint] = []
    
    // Right stick metrics
    @Published public var rightRestingOffset: Float = 0.0
    @Published public var rightMaxRestingDrift: Float = 0.0
    @Published public var rightHistoryTrail: [CGPoint] = []
    
    // Circularity Test State
    @Published public var isCircularityTestActive: Bool = false
    @Published public var activeTestStick: StickSide = .left
    @Published public var leftCircularityBins: [CircularityPoint] = []
    @Published public var rightCircularityBins: [CircularityPoint] = []
    
    private let maxTrailPoints = 30
    
    public init() {
        resetCircularityTest(for: .left)
        resetCircularityTest(for: .right)
    }
    
    public func resetCircularityTest(for stick: StickSide) {
        var bins: [CircularityPoint] = []
        let binAngle = 360.0 / Double(Self.numBins)
        for i in 0..<Self.numBins {
            let angle = Double(i) * binAngle
            bins.append(CircularityPoint(id: i, angleDeg: angle, maxDistance: 0.0, sampleX: 0, sampleY: 0))
        }
        if stick == .left {
            leftCircularityBins = bins
        } else {
            rightCircularityBins = bins
        }
    }
    
    public func resetDriftStats() {
        leftRestingOffset = 0
        leftMaxRestingDrift = 0
        leftHistoryTrail.removeAll()
        rightRestingOffset = 0
        rightMaxRestingDrift = 0
        rightHistoryTrail.removeAll()
        resetCircularityTest(for: .left)
        resetCircularityTest(for: .right)
    }
    
    public func update(leftX: Float, leftY: Float, rightX: Float, rightY: Float) {
        let leftDist = sqrt(leftX * leftX + leftY * leftY)
        let rightDist = sqrt(rightX * rightX + rightY * rightY)
        
        // Update resting offsets
        leftRestingOffset = leftDist
        if leftDist > leftMaxRestingDrift {
            leftMaxRestingDrift = leftDist
        }
        
        rightRestingOffset = rightDist
        if rightDist > rightMaxRestingDrift {
            rightMaxRestingDrift = rightDist
        }
        
        // Update trail
        leftHistoryTrail.append(CGPoint(x: CGFloat(leftX), y: CGFloat(leftY)))
        if leftHistoryTrail.count > maxTrailPoints {
            leftHistoryTrail.removeFirst()
        }
        
        rightHistoryTrail.append(CGPoint(x: CGFloat(rightX), y: CGFloat(rightY)))
        if rightHistoryTrail.count > maxTrailPoints {
            rightHistoryTrail.removeFirst()
        }
        
        // If circularity test is running
        if isCircularityTestActive {
            if activeTestStick == .left {
                recordCircularitySample(x: leftX, y: leftY, dist: leftDist, bins: &leftCircularityBins)
            } else {
                recordCircularitySample(x: rightX, y: rightY, dist: rightDist, bins: &rightCircularityBins)
            }
        }
    }
    
    private func recordCircularitySample(x: Float, y: Float, dist: Float, bins: inout [CircularityPoint]) {
        guard dist > 0.4 else { return } // only sample when pushed towards edge
        let rad = atan2(Double(y), Double(x))
        var deg = rad * 180.0 / .pi
        if deg < 0 { deg += 360.0 }
        
        let binWidth = 360.0 / Double(Self.numBins)
        let binIdx = min(Self.numBins - 1, max(0, Int(floor(deg / binWidth))))
        
        if dist > bins[binIdx].maxDistance {
            bins[binIdx].maxDistance = dist
            bins[binIdx].sampleX = x
            bins[binIdx].sampleY = y
        }
    }
    
    public func completionPercentage(for stick: StickSide) -> Double {
        let bins = stick == .left ? leftCircularityBins : rightCircularityBins
        let tested = bins.filter { $0.maxDistance > 0.5 }.count
        return (Double(tested) / Double(Self.numBins)) * 100.0
    }
    
    public func averageCircularityError(for stick: StickSide) -> Float {
        let bins = stick == .left ? leftCircularityBins : rightCircularityBins
        let validBins = bins.filter { $0.maxDistance > 0.2 }
        guard !validBins.isEmpty else { return 0.0 }
        let totalError = validBins.reduce(0.0) { $0 + $1.errorPercentage }
        return totalError / Float(validBins.count)
    }
    
    public func maxCircularityError(for stick: StickSide) -> Float {
        let bins = stick == .left ? leftCircularityBins : rightCircularityBins
        let validBins = bins.filter { $0.maxDistance > 0.2 }
        return validBins.map { $0.errorPercentage }.max() ?? 0.0
    }
    
    public func rating(for stick: StickSide) -> (text: String, color: Color) {
        let avgError = averageCircularityError(for: stick)
        let completion = completionPercentage(for: stick)
        if completion < 60 {
            return ("Incomplete (Rotate stick 360°)", .secondary)
        }
        if avgError < 5.0 {
            return ("Exceptional (< 5%)", .green)
        } else if avgError < 10.0 {
            return ("Good (5 - 10%)", .blue)
        } else if avgError < 16.0 {
            return ("Acceptable (10 - 16%)", .orange)
        } else {
            return ("High Deviation (> 16%)", .red)
        }
    }
}
