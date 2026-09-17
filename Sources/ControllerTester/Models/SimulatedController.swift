import Foundation
import SwiftUI

@MainActor
public final class SimulatedController: ObservableObject {
    @Published public var isRunning: Bool = false
    @Published public var demoSpeed: Double = 1.0
    
    private var timer: Timer?
    private var timeStep: Double = 0.0
    
    private weak var gamepadState: GamepadState?
    private weak var inputLog: InputLogManager?
    private weak var driftManager: DriftDiagnosticManager?
    
    public init() {}
    
    public func attach(state: GamepadState, log: InputLogManager, drift: DriftDiagnosticManager) {
        self.gamepadState = state
        self.inputLog = log
        self.driftManager = drift
    }
    
    public func start() {
        guard !isRunning else { return }
        isRunning = true
        gamepadState?.isSimulated = true
        gamepadState?.vendorName = "Simulated Controller"
        gamepadState?.productCategory = "Simulated Gamepad"
        gamepadState?.isConnected = true
        gamepadState?.hasHaptics = true
        gamepadState?.batteryLevel = 0.85
        
        timer?.invalidate()
        // Run simulation at 60 Hz
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.tick()
            }
        }
    }
    
    public func stop() {
        isRunning = false
        timer?.invalidate()
        timer = nil
        gamepadState?.resetToNeutral()
    }
    
    private func tick() {
        guard let state = gamepadState else { return }
        timeStep += (1.0 / 60.0) * demoSpeed
        let t = timeStep
        
        // 1. Left Stick: Smooth circular orbital test
        let lx = Float(cos(t * 1.5) * 0.9)
        let ly = Float(sin(t * 1.5) * 0.9)
        state.leftStick = ThumbstickState(x: lx, y: ly)
        
        // 2. Right Stick: Figure-8 (Lissajous curve)
        let rx = Float(sin(t * 2.0) * 0.8)
        let ry = Float(sin(t * 4.0) * 0.7)
        state.rightStick = ThumbstickState(x: rx, y: ry)
        
        // 3. Triggers: Pulsing analog squeeze
        let lt = Float(max(0, sin(t * 1.2)))
        let rt = Float(max(0, cos(t * 1.4)))
        state.leftTrigger.update(pressed: lt > 0.1, value: lt)
        state.rightTrigger.update(pressed: rt > 0.1, value: rt)
        
        // 4. Face buttons & Bumpers periodic activation
        let modT = Int(t * 2.0) % 12
        state.buttonA.update(pressed: modT == 0, value: modT == 0 ? 1.0 : 0.0)
        state.buttonB.update(pressed: modT == 1, value: modT == 1 ? 1.0 : 0.0)
        state.buttonX.update(pressed: modT == 2, value: modT == 2 ? 1.0 : 0.0)
        state.buttonY.update(pressed: modT == 3, value: modT == 3 ? 1.0 : 0.0)
        state.leftShoulder.update(pressed: modT == 4, value: modT == 4 ? 1.0 : 0.0)
        state.rightShoulder.update(pressed: modT == 5, value: modT == 5 ? 1.0 : 0.0)
        state.buttonL4.update(pressed: modT == 6, value: modT == 6 ? 1.0 : 0.0)
        state.buttonR4.update(pressed: modT == 7, value: modT == 7 ? 1.0 : 0.0)
        state.leftStickButton.update(pressed: modT == 8, value: modT == 8 ? 1.0 : 0.0)
        state.rightStickButton.update(pressed: modT == 9, value: modT == 9 ? 1.0 : 0.0)
        state.paddle1.update(pressed: modT == 10, value: modT == 10 ? 1.0 : 0.0)
        state.paddle2.update(pressed: modT == 11, value: modT == 11 ? 1.0 : 0.0)
        
        // 5. D-Pad
        let dpadMod = Int(t * 1.5) % 4
        state.dpadUp.update(pressed: dpadMod == 0, value: dpadMod == 0 ? 1.0 : 0.0)
        state.dpadRight.update(pressed: dpadMod == 1, value: dpadMod == 1 ? 1.0 : 0.0)
        state.dpadDown.update(pressed: dpadMod == 2, value: dpadMod == 2 ? 1.0 : 0.0)
        state.dpadLeft.update(pressed: dpadMod == 3, value: dpadMod == 3 ? 1.0 : 0.0)
        state.dpadX = dpadMod == 1 ? 1.0 : (dpadMod == 3 ? -1.0 : 0.0)
        state.dpadY = dpadMod == 0 ? 1.0 : (dpadMod == 2 ? -1.0 : 0.0)
        
        // 6. Motion (Pitch / Roll / Yaw & dynamic acceleration)
        let simPitch = sin(t * 1.0) * 0.45 // in radians (~25°)
        let simRoll = cos(t * 0.8) * 0.55  // in radians (~31°)
        let simYaw = sin(t * 0.5) * 0.35   // in radians (~20°)
        let rotX = cos(t * 1.0) * 0.45 * 45.0 // deg/s
        let rotY = -sin(t * 0.8) * 0.55 * 45.0 // deg/s
        let rotZ = cos(t * 0.5) * 0.35 * 45.0 // deg/s
        let gravX = sin(simRoll) * cos(simPitch)
        let gravY = -sin(simPitch)
        let gravZ = -cos(simRoll) * cos(simPitch)
        let uax = sin(t * 2.5) * 0.25
        let uay = cos(t * 3.0) * 0.20
        let uaz = sin(t * 1.8) * 0.15
        
        state.motion = ControllerMotionState(
            hasMotion: true,
            pitch: simPitch,
            roll: simRoll,
            yaw: simYaw,
            rotationRateX: rotX * .pi / 180.0,
            rotationRateY: rotY * .pi / 180.0,
            rotationRateZ: rotZ * .pi / 180.0,
            gravityX: gravX,
            gravityY: gravY,
            gravityZ: gravZ,
            userAccelX: uax,
            userAccelY: uay,
            userAccelZ: uaz
        )
        
        // Record telemetry and diagnostics
        state.recordEvent()
        driftManager?.update(leftX: lx, leftY: ly, rightX: rx, rightY: ry)
        
        // Periodically log an event
        if Int(t * 10) % 20 == 0 {
            inputLog?.log(
                element: "Left Thumbstick",
                category: .thumbstick,
                valueDescription: String(format: "X: %+.2f, Y: %+.2f", lx, ly)
            )
        }
    }
}
