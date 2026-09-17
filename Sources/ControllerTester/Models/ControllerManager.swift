import Foundation
import Combine
import GameController
import SwiftUI
import IOKit
import IOKit.hid
import EightBitDoKit

@MainActor
public final class ControllerManager: ObservableObject {
    @Published public var connectedControllers: [GCController] = []
    @Published public var selectedController: GCController? = nil
    @Published public var isDiscoveringWireless: Bool = false
    @Published public var monitorBackgroundEvents: Bool = true {
        didSet {
            GCController.shouldMonitorBackgroundEvents = monitorBackgroundEvents
        }
    }
    @Published public var isSimulatedMode: Bool = false
    
    public let state: GamepadState
    public let inputLog: InputLogManager
    public let driftManager: DriftDiagnosticManager
    public let hapticsManager: HapticsManager
    public let simulator: SimulatedController
    
    private var cancellables = Set<AnyCancellable>()
    
    private let standardElementKeys: Set<String> = [
        "Button A", "Button B", "Button X", "Button Y",
        "Left Shoulder", "Right Shoulder", "Left Trigger", "Right Trigger",
        "Left Thumbstick Button", "Right Thumbstick Button",
        "Button Menu", "Button Options", "Button Home",
        "Direction Pad Up", "Direction Pad Down", "Direction Pad Left", "Direction Pad Right"
    ]
    
    public init() {
        self.state = GamepadState()
        self.inputLog = InputLogManager()
        self.driftManager = DriftDiagnosticManager()
        self.hapticsManager = HapticsManager()
        self.simulator = SimulatedController()
        
        simulator.attach(state: state, log: inputLog, drift: driftManager)
        
        // Enable background controller event monitoring by default
        GCController.shouldMonitorBackgroundEvents = true
        
        setupNotificationObservers()
        setupEightBitDoSubscription()
        refreshControllers()
    }
    
    private func setupNotificationObservers() {
        NotificationCenter.default.publisher(for: .GCControllerDidConnect)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self = self else { return }
                if let controller = notification.object as? GCController {
                    self.controllerDidConnect(controller)
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .GCControllerDidDisconnect)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self = self else { return }
                if let controller = notification.object as? GCController {
                    self.controllerDidDisconnect(controller)
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupEightBitDoSubscription() {
        EightBitDoDevice.shared.start()
        
        EightBitDoDevice.shared.onStateChanged = { [weak self] ebState in
            Task { @MainActor [weak self] in
                self?.handleEightBitDoState(ebState)
            }
        }
        
        EightBitDoDevice.shared.$isConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isConnected in
                guard let self = self else { return }
                if isConnected && (self.selectedController == nil || self.isSimulatedMode) {
                    self.isSimulatedMode = false
                    self.state.isConnected = true
                    self.state.isSimulated = false
                    self.state.vendorName = "8BitDo Ultimate 2 (Native D-Input)"
                    self.state.productCategory = "2.4G Wireless D-Input"
                    self.state.isHidPCMode = true
                    self.state.hardwareAdvisory = nil
                    self.state.motion.hasMotion = true
                    self.state.hasHaptics = true
                }
            }
            .store(in: &cancellables)
    }
    
    private func handleEightBitDoState(_ ebState: EightBitDoState) {
        guard !isSimulatedMode else { return }
        
        // 1. Back Paddles (M1 & M2) and Extra Bumpers (L4 & R4)
        state.paddle1.update(pressed: ebState.paddleM1, value: ebState.paddleM1 ? 1.0 : 0.0)
        state.paddle2.update(pressed: ebState.paddleM2, value: ebState.paddleM2 ? 1.0 : 0.0)
        state.buttonL4.update(pressed: ebState.buttonL4, value: ebState.buttonL4 ? 1.0 : 0.0)
        state.buttonR4.update(pressed: ebState.buttonR4, value: ebState.buttonR4 ? 1.0 : 0.0)
        
        // Home Button from raw EightBitDo report
        state.buttonHome.update(pressed: ebState.buttonHome, value: ebState.buttonHome ? 1.0 : 0.0)
        
        // Linear user acceleration: total acceleration minus normalized gravity vector
        let uax = Double(ebState.acceleration.x - ebState.gravity.x)
        let uay = Double(ebState.acceleration.y - ebState.gravity.y)
        let uaz = Double(ebState.acceleration.z - ebState.gravity.z)
        
        // 2. Motion IMU Attitude & Rates (Pitch = gyRad/Y rate, Roll = gxRad/X rate)
        state.motion = ControllerMotionState(
            hasMotion: true,
            pitch: Double(ebState.pitch) * .pi / 180.0,
            roll: Double(ebState.roll) * .pi / 180.0,
            yaw: Double(ebState.yaw) * .pi / 180.0,
            rotationRateX: Double(ebState.angularVelocityRad.y),
            rotationRateY: Double(ebState.angularVelocityRad.x),
            rotationRateZ: Double(ebState.angularVelocityRad.z),
            gravityX: Double(ebState.acceleration.x),
            gravityY: Double(ebState.acceleration.y),
            gravityZ: Double(ebState.acceleration.z),
            userAccelX: uax,
            userAccelY: uay,
            userAccelZ: uaz
        )
        
        // 3. If no Apple GCController is active, drive full gamepad state from EightBitDoKit
        if selectedController == nil {
            state.buttonA.update(pressed: ebState.buttonA, value: ebState.buttonA ? 1.0 : 0.0)
            state.buttonB.update(pressed: ebState.buttonB, value: ebState.buttonB ? 1.0 : 0.0)
            state.buttonX.update(pressed: ebState.buttonX, value: ebState.buttonX ? 1.0 : 0.0)
            state.buttonY.update(pressed: ebState.buttonY, value: ebState.buttonY ? 1.0 : 0.0)
            
            state.leftShoulder.update(pressed: ebState.buttonLB, value: ebState.buttonLB ? 1.0 : 0.0)
            state.rightShoulder.update(pressed: ebState.buttonRB, value: ebState.buttonRB ? 1.0 : 0.0)
            state.leftTrigger.update(pressed: ebState.leftTrigger > 0.05, value: ebState.leftTrigger)
            state.rightTrigger.update(pressed: ebState.rightTrigger > 0.05, value: ebState.rightTrigger)
            
            state.dpadUp.update(pressed: ebState.dpadUp, value: ebState.dpadUp ? 1.0 : 0.0)
            state.dpadDown.update(pressed: ebState.dpadDown, value: ebState.dpadDown ? 1.0 : 0.0)
            state.dpadLeft.update(pressed: ebState.dpadLeft, value: ebState.dpadLeft ? 1.0 : 0.0)
            state.dpadRight.update(pressed: ebState.dpadRight, value: ebState.dpadRight ? 1.0 : 0.0)
            
            let lx = Float(ebState.leftStick.x)
            let ly = Float(ebState.leftStick.y)
            let rx = Float(ebState.rightStick.x)
            let ry = Float(ebState.rightStick.y)
            
            state.leftStick = ThumbstickState(x: lx, y: ly)
            state.rightStick = ThumbstickState(x: rx, y: ry)
            driftManager.update(leftX: lx, leftY: ly, rightX: rx, rightY: ry)
            
            state.leftStickButton.update(pressed: ebState.buttonL3, value: ebState.buttonL3 ? 1.0 : 0.0)
            state.rightStickButton.update(pressed: ebState.buttonR3, value: ebState.buttonR3 ? 1.0 : 0.0)
            
            state.buttonMenu.update(pressed: ebState.buttonStart, value: ebState.buttonStart ? 1.0 : 0.0)
            state.buttonOptions.update(pressed: ebState.buttonSelect, value: ebState.buttonSelect ? 1.0 : 0.0)
            state.buttonHome.update(pressed: ebState.buttonHome, value: ebState.buttonHome ? 1.0 : 0.0)
            
            state.recordEvent()
        }
    }
    
    public func refreshControllers() {
        let currentList = GCController.controllers()
        self.connectedControllers = currentList
        
        if let first = currentList.first {
            selectController(first)
        } else if EightBitDoDevice.shared.isConnected {
            self.isSimulatedMode = false
            self.state.isConnected = true
            self.state.isSimulated = false
            self.state.vendorName = "8BitDo Ultimate 2 (Native D-Input)"
            self.state.productCategory = "2.4G Wireless D-Input"
            self.state.isHidPCMode = true
            self.state.hardwareAdvisory = nil
            self.state.motion.hasMotion = true
            self.state.hasHaptics = true
        } else {
            // No physical controllers connected - fallback to simulated mode
            setSimulatedMode(true)
        }
    }
    
    public func selectController(_ controller: GCController?) {
        guard let controller = controller else {
            setSimulatedMode(true)
            return
        }
        
        // Disable simulation if physical controller is selected
        setSimulatedMode(false)
        selectedController = controller
        
        // Update state metadata
        state.id = "\(controller.hashValue)"
        state.vendorName = controller.vendorName ?? "Game Controller"
        state.productCategory = controller.productCategory
        state.playerIndex = controller.playerIndex.rawValue + 1
        state.isConnected = true
        state.isSimulated = false
        state.hasHaptics = (controller.haptics != nil)
        
        // Link haptics sub-manager
        hapticsManager.setController(controller)
        
        // Attach input listeners (and direct HID fallback if needed)
        attachHandlers(to: controller)
        
        // 8BitDo hardware profile diagnosis
        let vendor = controller.vendorName ?? ""
        let cat = controller.productCategory
        if vendor.localizedCaseInsensitiveContains("8BitDo") || vendor.localizedCaseInsensitiveContains("PC") || cat == "HID" {
            state.isHidPCMode = true
            state.hasHaptics = hapticsManager.isDirectHIDActive || (controller.haptics != nil)
            state.hardwareAdvisory = nil
        } else {
            state.isHidPCMode = false
            state.hardwareAdvisory = nil
        }
        
        if let battery = controller.battery {
            state.batteryLevel = battery.batteryLevel
            state.batteryState = battery.batteryState
        } else {
            state.batteryLevel = nil
            state.batteryState = nil
        }
        
        // Populate extra/paddle buttons (e.g. 8BitDo M1, M2, L4, R4)
        for (key, element) in controller.physicalInputProfile.elements {
            if let btn = element as? GCControllerButtonInput {
                if !standardElementKeys.contains(key) {
                    state.updateDynamicButton(
                        key: key,
                        name: element.localizedName ?? key,
                        symbol: element.sfSymbolsName,
                        pressed: btn.isPressed,
                        value: btn.value
                    )
                }
            }
        }
        
        inputLog.log(
            element: "Controller Connected",
            category: .system,
            valueDescription: "\(controller.vendorName ?? "Device") (\(controller.productCategory))"
        )
    }
    
    public func setSimulatedMode(_ enabled: Bool) {
        isSimulatedMode = enabled
        if enabled {
            selectedController = nil
            hapticsManager.setController(nil)
            simulator.start()
            inputLog.log(
                element: "Simulation Mode",
                category: .system,
                valueDescription: "Virtual controller simulation active"
            )
        } else {
            simulator.stop()
        }
    }
    
    public func toggleWirelessDiscovery() {
        if isDiscoveringWireless {
            GCController.stopWirelessControllerDiscovery()
            isDiscoveringWireless = false
            inputLog.log(element: "Wireless Discovery", category: .system, valueDescription: "Discovery stopped")
        } else {
            isDiscoveringWireless = true
            inputLog.log(element: "Wireless Discovery", category: .system, valueDescription: "Searching for wireless controllers...")
            GCController.startWirelessControllerDiscovery { [weak self] in
                Task { @MainActor [weak self] in
                    self?.isDiscoveringWireless = false
                    self?.inputLog.log(element: "Wireless Discovery", category: .system, valueDescription: "Discovery session finished")
                }
            }
        }
    }
    
    private func controllerDidConnect(_ controller: GCController) {
        if !connectedControllers.contains(controller) {
            connectedControllers.append(controller)
        }
        if selectedController == nil || isSimulatedMode {
            selectController(controller)
        }
    }
    
    private func controllerDidDisconnect(_ controller: GCController) {
        connectedControllers.removeAll { $0 === controller }
        inputLog.log(
            element: "Controller Disconnected",
            category: .system,
            valueDescription: "\(controller.vendorName ?? "Device") disconnected"
        )
        
        if selectedController === controller {
            if let next = connectedControllers.first {
                selectController(next)
            } else {
                setSimulatedMode(true)
            }
        }
    }
    
    private func attachHandlers(to controller: GCController) {
        // Extended Gamepad (Standard inputs)
        if let extended = controller.extendedGamepad {
            extended.valueChangedHandler = { [weak self] (gamepad, element) in
                Task { @MainActor [weak self] in
                    self?.handleExtendedInput(gamepad: gamepad, element: element)
                }
            }
            
            // Explicit Home Button handler on ExtendedGamepad (disables macOS system gesture capture)
            if let home = extended.buttonHome {
                home.preferredSystemGestureState = .disabled
                home.valueChangedHandler = { [weak self] (button, value, pressed) in
                    Task { @MainActor [weak self] in
                        self?.state.buttonHome.update(pressed: pressed, value: value)
                        self?.logElementEvent(button)
                    }
                }
                home.pressedChangedHandler = { [weak self] (button, value, pressed) in
                    Task { @MainActor [weak self] in
                        self?.state.buttonHome.update(pressed: pressed, value: value)
                        self?.logElementEvent(button)
                    }
                }
            }
            
            // Disable system gestures on Start and Select
            extended.buttonMenu.preferredSystemGestureState = .disabled
            extended.buttonOptions?.preferredSystemGestureState = .disabled
        }
        
        // Physical Input Profile for Home and custom buttons
        for (key, element) in controller.physicalInputProfile.elements {
            if let btn = element as? GCControllerButtonInput {
                let nameLower = (element.localizedName ?? key).lowercased()
                let symLower = (element.sfSymbolsName ?? "").lowercased()
                if key == GCInputButtonHome || nameLower.contains("home") || symLower.contains("house") || symLower.contains("home") || nameLower.contains("guide") {
                    btn.preferredSystemGestureState = .disabled
                    btn.valueChangedHandler = { [weak self] (button, value, pressed) in
                        Task { @MainActor [weak self] in
                            self?.state.buttonHome.update(pressed: pressed, value: value)
                            self?.logElementEvent(button)
                        }
                    }
                    btn.pressedChangedHandler = { [weak self] (button, value, pressed) in
                        Task { @MainActor [weak self] in
                            self?.state.buttonHome.update(pressed: pressed, value: value)
                            self?.logElementEvent(button)
                        }
                    }
                }
            }
        }
        
        // Physical Input Profile for extra / custom buttons (M1, M2, L4, R4)
        controller.physicalInputProfile.valueDidChangeHandler = { [weak self] (profile, element) in
            Task { @MainActor [weak self] in
                self?.handleProfileElement(element)
            }
        }
        
        // Motion handler: for non-8BitDo controllers (e.g. DualSense), use Apple GCMotion if present
        let vendor = controller.vendorName ?? ""
        let is8BitDo = vendor.localizedCaseInsensitiveContains("8BitDo") || controller.productCategory == "HID"
        
        if !is8BitDo, let motion = controller.motion {
            if motion.sensorsRequireManualActivation {
                motion.sensorsActive = true
            }
            motion.sensorsActive = true
            motion.valueChangedHandler = { [weak self] motion in
                Task { @MainActor [weak self] in
                    self?.handleMotionUpdate(motion)
                }
            }
        }
    }
    
    public func resetMotionOrientation() {
        EightBitDoDevice.shared.resetOrientation()
    }
    
    private func handleExtendedInput(gamepad: GCExtendedGamepad, element: GCControllerElement) {
        state.recordEvent()
        
        // Thumbsticks
        let lx = gamepad.leftThumbstick.xAxis.value
        let ly = gamepad.leftThumbstick.yAxis.value
        let rx = gamepad.rightThumbstick.xAxis.value
        let ry = gamepad.rightThumbstick.yAxis.value
        
        state.leftStick = ThumbstickState(x: lx, y: ly)
        state.rightStick = ThumbstickState(x: rx, y: ry)
        driftManager.update(leftX: lx, leftY: ly, rightX: rx, rightY: ry)
        
        // D-Pad
        let dpad = gamepad.dpad
        state.dpadUp.update(pressed: dpad.up.isPressed, value: dpad.up.value)
        state.dpadDown.update(pressed: dpad.down.isPressed, value: dpad.down.value)
        state.dpadLeft.update(pressed: dpad.left.isPressed, value: dpad.left.value)
        state.dpadRight.update(pressed: dpad.right.isPressed, value: dpad.right.value)
        state.dpadX = dpad.xAxis.value
        state.dpadY = dpad.yAxis.value
        
        // Face buttons
        state.buttonA.update(pressed: gamepad.buttonA.isPressed, value: gamepad.buttonA.value)
        state.buttonB.update(pressed: gamepad.buttonB.isPressed, value: gamepad.buttonB.value)
        state.buttonX.update(pressed: gamepad.buttonX.isPressed, value: gamepad.buttonX.value)
        state.buttonY.update(pressed: gamepad.buttonY.isPressed, value: gamepad.buttonY.value)
        
        // Shoulders & Triggers
        state.leftShoulder.update(pressed: gamepad.leftShoulder.isPressed, value: gamepad.leftShoulder.value)
        state.rightShoulder.update(pressed: gamepad.rightShoulder.isPressed, value: gamepad.rightShoulder.value)
        state.leftTrigger.update(pressed: gamepad.leftTrigger.isPressed, value: gamepad.leftTrigger.value)
        state.rightTrigger.update(pressed: gamepad.rightTrigger.isPressed, value: gamepad.rightTrigger.value)
        
        // Stick clicks (L3 / R3)
        if let l3 = gamepad.leftThumbstickButton {
            state.leftStickButton.update(pressed: l3.isPressed, value: l3.value)
        }
        if let r3 = gamepad.rightThumbstickButton {
            state.rightStickButton.update(pressed: r3.isPressed, value: r3.value)
        }
        
        // System buttons
        state.buttonMenu.update(pressed: gamepad.buttonMenu.isPressed, value: gamepad.buttonMenu.value)
        if let opts = gamepad.buttonOptions {
            state.buttonOptions.update(pressed: opts.isPressed, value: opts.value)
        }
        if let home = gamepad.buttonHome {
            state.buttonHome.update(pressed: home.isPressed, value: home.value)
        }
        
        // Log element event
        logElementEvent(element)
    }
    
    private func handleProfileElement(_ element: GCControllerElement) {
        guard let btn = element as? GCControllerButtonInput else { return }
        let key = element.localizedName ?? element.sfSymbolsName ?? "Extra Button"
        
        // Map specific hardware extra buttons
        let sym = element.sfSymbolsName?.lowercased() ?? ""
        let nameLower = key.lowercased()
        if nameLower.contains("home") || sym.contains("house") || sym.contains("home") || nameLower.contains("guide") {
            state.buttonHome.update(pressed: btn.isPressed, value: btn.value)
            logElementEvent(element)
            return
        } else if nameLower.contains("m1") || sym.contains("m1") {
            state.paddle1.update(pressed: btn.isPressed, value: btn.value)
        } else if nameLower.contains("m2") || sym.contains("m2") {
            state.paddle2.update(pressed: btn.isPressed, value: btn.value)
        } else if nameLower.contains("l4") || sym.contains("l4") {
            state.buttonL4.update(pressed: btn.isPressed, value: btn.value)
        } else if nameLower.contains("r4") || sym.contains("r4") {
            state.buttonR4.update(pressed: btn.isPressed, value: btn.value)
        }
        
        // Only track in dynamic list if not already one of the standard face/shoulder/dpad buttons
        if !standardElementKeys.contains(key) {
            state.updateDynamicButton(
                key: key,
                name: key,
                symbol: element.sfSymbolsName,
                pressed: btn.isPressed,
                value: btn.value
            )
            state.recordEvent()
            logElementEvent(element)
        }
    }
    
    private func handleMotionUpdate(_ motion: GCMotion) {
        let q = motion.attitude
        // Euler conversion from quaternion (x, y, z, w)
        // Pitch (tilting controller back / forward around X-axis)
        let sinPitch = 2 * (q.w * q.x + q.y * q.z)
        let cosPitch = 1 - 2 * (q.x * q.x + q.y * q.y)
        let pitch = atan2(sinPitch, cosPitch)
        
        // Roll (tilting controller left / right around Y-axis)
        let sinRoll = 2 * (q.w * q.y - q.z * q.x)
        let roll: Double
        if abs(sinRoll) >= 1 {
            roll = copysign(.pi / 2, sinRoll)
        } else {
            roll = asin(sinRoll)
        }
        
        let siny_cosp = 2 * (q.w * q.z + q.x * q.y)
        let cosy_cosp = 1 - 2 * (q.y * q.y + q.z * q.z)
        let yaw = atan2(siny_cosp, cosy_cosp)
        
        state.motion = ControllerMotionState(
            hasMotion: true,
            pitch: pitch,
            roll: roll,
            yaw: yaw,
            rotationRateX: motion.rotationRate.x,
            rotationRateY: motion.rotationRate.y,
            rotationRateZ: motion.rotationRate.z,
            gravityX: motion.gravity.x,
            gravityY: motion.gravity.y,
            gravityZ: motion.gravity.z,
            userAccelX: motion.userAcceleration.x,
            userAccelY: motion.userAcceleration.y,
            userAccelZ: motion.userAcceleration.z
        )
    }
    
    private func logElementEvent(_ element: GCControllerElement) {
        let name = element.localizedName ?? element.sfSymbolsName ?? "Input"
        
        if let btn = element as? GCControllerButtonInput {
            let cat: InputCategory = (element === selectedController?.extendedGamepad?.leftTrigger || element === selectedController?.extendedGamepad?.rightTrigger) ? .trigger : .button
            let desc = btn.isPressed ? String(format: "Pressed (%.2f)", btn.value) : "Released"
            inputLog.log(element: name, category: cat, valueDescription: desc, isPressed: btn.isPressed)
        } else if let dpad = element as? GCControllerDirectionPad {
            let desc = String(format: "X: %+.2f, Y: %+.2f", dpad.xAxis.value, dpad.yAxis.value)
            inputLog.log(element: name, category: .thumbstick, valueDescription: desc)
        } else if let axis = element as? GCControllerAxisInput {
            let desc = String(format: "Value: %+.2f", axis.value)
            inputLog.log(element: name, category: .thumbstick, valueDescription: desc)
        }
    }
}
