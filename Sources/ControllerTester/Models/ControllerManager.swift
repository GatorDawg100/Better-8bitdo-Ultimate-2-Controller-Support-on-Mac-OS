import Foundation
import Combine
import GameController
import SwiftUI
import IOKit
import IOKit.hid
import EightBitDoKit
import DualSenseEmulationKit

private final class HIDBuffer: @unchecked Sendable {
    let pointer: UnsafeMutablePointer<UInt8> = .allocate(capacity: 64)
    deinit {
        pointer.deallocate()
    }
}

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
    
    // Direct native macOS USB HID motion reader (for 8BitDo D-Input / 2.4G IMU packet)
    private var hidMotionManager: IOHIDManager?
    private var directHIDDevice: IOHIDDevice?
    private var reportBuffer: HIDBuffer?
    
    // 6-Axis IMU sensor fusion state
    private var filterPitch: Double = 0.0
    private var filterRoll: Double = 0.0
    private var filterYaw: Double = 0.0
    private var lastMotionTimestamp: Double = 0.0
    private var motionReportCount: Int = 0
    
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
        setupDirectHIDMotion()
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
        
        // 1. Back Paddles (M1 & M2)
        state.paddle1.update(pressed: ebState.paddleM1, value: ebState.paddleM1 ? 1.0 : 0.0)
        state.paddle2.update(pressed: ebState.paddleM2, value: ebState.paddleM2 ? 1.0 : 0.0)
        
        // 2. Motion IMU Attitude & Rates
        state.motion = ControllerMotionState(
            hasMotion: true,
            pitch: Double(ebState.pitch) * .pi / 180.0,
            roll: Double(ebState.roll) * .pi / 180.0,
            yaw: Double(ebState.yaw) * .pi / 180.0,
            rotationRateX: Double(ebState.angularVelocityDeg.x),
            rotationRateY: Double(ebState.angularVelocityDeg.y),
            rotationRateZ: Double(ebState.angularVelocityDeg.z),
            gravityX: Double(ebState.acceleration.x),
            gravityY: Double(ebState.acceleration.y),
            gravityZ: Double(ebState.acceleration.z),
            userAccelX: 0.0,
            userAccelY: 0.0,
            userAccelZ: 0.0
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
            
            state.leftStick = ThumbstickState(x: Float(ebState.leftStick.x), y: Float(ebState.leftStick.y))
            state.rightStick = ThumbstickState(x: Float(ebState.rightStick.x), y: Float(ebState.rightStick.y))
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
            state.hardwareAdvisory = """
            8BitDo Direct Hardware Integration Active!
            
            • 6-Axis Gyroscope & Accelerometer: Streaming live from 8BitDo's native 6-axis IMU packet.
            • Dual-Motor Haptics: Streaming live via USB Force-Feedback (PID Report ID 5).
            • Extra Back Paddle Buttons: M1, M2, L4, and R4 are active in the Button Matrix.
            
            Both Gyro and Haptics are now working directly in your current 2.4 GHz / D-Input mode!
            """
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
            detachDirectHIDMotion()
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
            setupDirectHIDMotion()
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
        detachDirectHIDMotion()
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
        }
        
        // Physical Input Profile for extra / custom buttons (M1, M2, L4, R4)
        controller.physicalInputProfile.valueDidChangeHandler = { [weak self] (profile, element) in
            Task { @MainActor [weak self] in
                self?.handleProfileElement(element)
            }
        }
        
        // Motion handler
        if let motion = controller.motion {
            if motion.sensorsRequireManualActivation {
                motion.sensorsActive = true
            }
            motion.sensorsActive = true
            motion.valueChangedHandler = { [weak self] motion in
                Task { @MainActor [weak self] in
                    self?.handleMotionUpdate(motion)
                }
            }
        } else {
            // Direct native macOS HID 6-axis IMU fallback for 8BitDo (Report ID 1, Bytes 15-26)
            setupDirectHIDMotion()
        }
    }
    
    // MARK: - Direct Native macOS USB HID IMU Integration
    
    public func setupDirectHIDMotion() {
        guard !isSimulatedMode else { return }
        
        if hidMotionManager == nil {
            let mgr = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
            let matchDict = [
                kIOHIDVendorIDKey as String: 0x2dc8
            ] as CFDictionary
            IOHIDManagerSetDeviceMatching(mgr, matchDict)
            
            let context = Unmanaged.passUnretained(self).toOpaque()
            IOHIDManagerRegisterDeviceMatchingCallback(mgr, { context, result, sender, device in
                guard let context = context else { return }
                let selfRef = Unmanaged<ControllerManager>.fromOpaque(context).takeUnretainedValue()
                selfRef.directHIDDeviceMatched(device)
            }, context)
            
            IOHIDManagerRegisterDeviceRemovalCallback(mgr, { context, result, sender, device in
                guard let context = context else { return }
                let selfRef = Unmanaged<ControllerManager>.fromOpaque(context).takeUnretainedValue()
                selfRef.directHIDDeviceRemoved(device)
            }, context)
            
            IOHIDManagerScheduleWithRunLoop(mgr, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
            _ = IOHIDManagerOpen(mgr, IOOptionBits(kIOHIDOptionsTypeNone))
            self.hidMotionManager = mgr
        }
        
        // If device is already present
        if let mgr = hidMotionManager,
           let deviceSet = IOHIDManagerCopyDevices(mgr) as? Set<IOHIDDevice>,
           let dev = deviceSet.first {
            directHIDDeviceMatched(dev)
        }
    }
    
    private func directHIDDeviceMatched(_ dev: IOHIDDevice) {
        if directHIDDevice === dev { return }
        detachDirectHIDMotion()
        
        _ = IOHIDDeviceOpen(dev, IOOptionBits(kIOHIDOptionsTypeNone))
        self.directHIDDevice = dev
        let buf = HIDBuffer()
        self.reportBuffer = buf
        
        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDDeviceRegisterInputReportCallback(dev, buf.pointer, 64, { context, result, sender, type, reportID, report, reportLength in
            guard reportLength >= 27, let context = context else { return }
            let mgr = Unmanaged<ControllerManager>.fromOpaque(context).takeUnretainedValue()
            mgr.handleDirectHIDMotionReport(report: report, length: reportLength)
        }, context)
        
        IOHIDDeviceScheduleWithRunLoop(dev, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        state.motion.hasMotion = true
    }
    
    private func directHIDDeviceRemoved(_ dev: IOHIDDevice) {
        if directHIDDevice === dev {
            detachDirectHIDMotion()
        }
    }
    
    public func resetMotionOrientation() {
        filterYaw = 0.0
        filterPitch = 0.0
        filterRoll = 0.0
        motionReportCount = 0
    }
    
    private func detachDirectHIDMotion() {
        if let dev = directHIDDevice {
            IOHIDDeviceUnscheduleFromRunLoop(dev, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
            if let buf = reportBuffer {
                IOHIDDeviceRegisterInputReportCallback(dev, buf.pointer, 64, nil, nil)
            }
            directHIDDevice = nil
        }
        reportBuffer = nil
    }
    
    nonisolated private func handleDirectHIDMotionReport(report: UnsafePointer<UInt8>, length: Int) {
        // 8BitDo 6-axis IMU packet:
        // Bytes 15-20: Accelerometer X, Y, Z (signed 16-bit little endian, 4096 LSB = 1.0G)
        // Bytes 21-26: Gyroscope X, Y, Z (signed 16-bit little endian)
        let rawAx = Int16(bitPattern: UInt16(report[15]) | (UInt16(report[16]) << 8))
        let rawAy = Int16(bitPattern: UInt16(report[17]) | (UInt16(report[18]) << 8))
        let rawAz = Int16(bitPattern: UInt16(report[19]) | (UInt16(report[20]) << 8))
        
        let ax = Double(rawAx) / 4096.0
        let ay = Double(rawAy) / 4096.0
        let az = Double(rawAz) / 4096.0
        
        let rawGx = Int16(bitPattern: UInt16(report[21]) | (UInt16(report[22]) << 8))
        let rawGy = Int16(bitPattern: UInt16(report[23]) | (UInt16(report[24]) << 8))
        let rawGz = Int16(bitPattern: UInt16(report[25]) | (UInt16(report[26]) << 8))
        
        // Convert to rad/s (~16.4 LSB per deg/s = 0.001065 rad/s per LSB)
        let gx = Double(rawGx) * 0.001065
        let gy = Double(rawGy) * 0.001065
        let gz = Double(rawGz) * 0.001065
        
        let accelPitch = atan2(ay, sqrt(ax * ax + az * az))
        let accelRoll = atan2(-ax, az)
        
        let now = ProcessInfo.processInfo.systemUptime
        
        // User acceleration: subtract gravity vector
        let mag = sqrt(ax * ax + ay * ay + az * az)
        let normGx = mag > 0.01 ? (ax / mag) : 0.0
        let normGy = mag > 0.01 ? (ay / mag) : 0.0
        let normGz = mag > 0.01 ? (az / mag) : 1.0
        let uax = ax - normGx
        let uay = ay - normGy
        let uaz = az - normGz
        
        MainActor.assumeIsolated {
            guard !self.isSimulatedMode else { return }
            
            let dt = (self.lastMotionTimestamp == 0.0) ? 0.016 : min(0.1, max(0.001, now - self.lastMotionTimestamp))
            self.lastMotionTimestamp = now
            self.motionReportCount += 1
            
            // Sensor fusion complementary filter
            if self.motionReportCount <= 2 {
                self.filterPitch = accelPitch
                self.filterRoll = accelRoll
            } else {
                let alpha = 0.92
                self.filterPitch = alpha * (self.filterPitch + gx * dt) + (1.0 - alpha) * accelPitch
                self.filterRoll = alpha * (self.filterRoll + gy * dt) + (1.0 - alpha) * accelRoll
                self.filterYaw += gz * dt
            }
            
            self.state.motion = ControllerMotionState(
                hasMotion: true,
                pitch: self.filterPitch,
                roll: self.filterRoll,
                yaw: self.filterYaw,
                rotationRateX: gx,
                rotationRateY: gy,
                rotationRateZ: gz,
                gravityX: ax,
                gravityY: ay,
                gravityZ: az,
                userAccelX: uax,
                userAccelY: uay,
                userAccelZ: uaz
            )
        }
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
        
        // Only track if not already one of the standard face/shoulder/dpad buttons
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
        let sinr_cosp = 2 * (q.w * q.x + q.y * q.z)
        let cosr_cosp = 1 - 2 * (q.x * q.x + q.y * q.y)
        let roll = atan2(sinr_cosp, cosr_cosp)
        
        let sinp = 2 * (q.w * q.y - q.z * q.x)
        let pitch: Double
        if abs(sinp) >= 1 {
            pitch = copysign(.pi / 2, sinp)
        } else {
            pitch = asin(sinp)
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
