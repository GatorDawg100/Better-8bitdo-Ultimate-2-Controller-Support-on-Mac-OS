import SwiftUI

public struct TriggerButtonHealthView: View {
    @ObservedObject var state: GamepadState
    
    public init(state: GamepadState) {
        self.state = state
    }
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Analog Triggers Detailed Gauges
                VStack(alignment: .leading, spacing: 12) {
                    Text("Analog Triggers (L2 / R2 / LT / RT)")
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    HStack(spacing: 16) {
                        TriggerBarView(
                            title: "Left Trigger (LT / L2)",
                            subtitle: "Analog Hall-Effect / Potentiometer",
                            value: state.leftTrigger.value,
                            isPressed: state.leftTrigger.isPressed,
                            pressCount: state.leftTrigger.pressCount,
                            color: .orange
                        )
                        
                        TriggerBarView(
                            title: "Right Trigger (RT / R2)",
                            subtitle: "Analog Hall-Effect / Potentiometer",
                            value: state.rightTrigger.value,
                            isPressed: state.rightTrigger.isPressed,
                            pressCount: state.rightTrigger.pressCount,
                            color: .orange
                        )
                    }
                }
                
                // Button Actuation Health Matrix
                ButtonMatrixView(state: state)
            }
            .padding(16)
        }
    }
}
