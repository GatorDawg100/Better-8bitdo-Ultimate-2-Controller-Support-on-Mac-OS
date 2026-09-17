import SwiftUI

public struct HapticsView: View {
    @ObservedObject var hapticsManager: HapticsManager
    let hasHaptics: Bool
    let hardwareAdvisory: String?
    
    public init(hapticsManager: HapticsManager, hasHaptics: Bool, hardwareAdvisory: String? = nil) {
        self.hapticsManager = hapticsManager
        self.hasHaptics = hasHaptics
        self.hardwareAdvisory = hardwareAdvisory
    }
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Unified Haptics Tester
                HapticsTesterView(haptics: hapticsManager, hasHaptics: hasHaptics)
            }
            .padding(16)
        }
    }
}
