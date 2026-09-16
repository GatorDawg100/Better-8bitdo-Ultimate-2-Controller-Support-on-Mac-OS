import Foundation
import CoreHaptics
import GameController
import SwiftUI
import IOKit
import IOKit.hid

public enum HapticPresetPattern: String, CaseIterable, Identifiable, Sendable {
    case quickTap = "Single Tap"
    case doubleTap = "Double Tap"
    case heartbeat = "Heartbeat"
    case heavyImpact = "Heavy Impact"
    case weaponBurst = "Weapon Burst"
    case continuous = "Continuous Buzz"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .quickTap: return "hand.tap"
        case .doubleTap: return "hand.tap.fill"
        case .heartbeat: return "heart.fill"
        case .heavyImpact: return "bolt.fill"
        case .weaponBurst: return "flame.fill"
        case .continuous: return "waveform"
        }
    }
}

@MainActor
public final class HapticsManager: ObservableObject {
    @Published public var intensity: Float = 0.80
    @Published public var sharpness: Float = 0.60
    @Published public var isVibrating: Bool = false
    @Published public var statusMessage: String = "Ready"
    @Published public var isDirectHIDActive: Bool = false
    
    private var engine: CHHapticEngine?
    private var activePlayer: CHHapticPatternPlayer?
    private var continuousPlayer: CHHapticAdvancedPatternPlayer?
    private weak var currentController: GCController?
    
    // Retained native macOS USB HID handles (keeps device open for 8BitDo D-Input / 2.4G Report ID 5)
    private var hidManager: IOHIDManager?
    private var directHIDDevice: IOHIDDevice?
    
    public init() {
        setupDirectHID()
    }
    
    public func setController(_ controller: GCController?) {
        self.currentController = controller
        stopHaptics()
        
        if let controller = controller, controller.haptics != nil {
            // Apple GameController CoreHaptics pathway
            isDirectHIDActive = false
            directHIDDevice = nil
            setupEngine()
        } else {
            // Direct native macOS USB HID Force-Feedback (PID Page 0x0F / Report ID 5)
            setupDirectHID()
            if directHIDDevice != nil {
                self.isDirectHIDActive = true
                self.statusMessage = "Direct macOS USB Force-Feedback Active (Whole Controller)"
            } else {
                self.isDirectHIDActive = false
                self.engine = nil
                if let c = controller {
                    statusMessage = "\(c.vendorName ?? "Controller") (Simulation Fallback)"
                } else {
                    statusMessage = "No controller connected (Simulation Mode)"
                }
            }
        }
    }
    
    public func setupEngine() {
        guard let controller = currentController, let haptics = controller.haptics else {
            engine = nil
            if isDirectHIDActive {
                statusMessage = "Direct macOS USB Force-Feedback Active"
            }
            return
        }
        
        do {
            let localityToUse: GCHapticsLocality = haptics.supportedLocalities.contains(.all) ? .all : .default
            guard let newEngine = haptics.createEngine(withLocality: localityToUse) else {
                statusMessage = "Unable to create haptic engine"
                return
            }
            
            engine = newEngine
            try engine?.start()
            statusMessage = "Apple CoreHaptics active"
        } catch {
            statusMessage = "Engine start failed: \(error.localizedDescription)"
        }
    }
    
    public func playPreset(_ preset: HapticPresetPattern) {
        isVibrating = true
        
        // 1. Direct macOS USB HID pathway (8BitDo D-Input / 2.4G)
        if directHIDDevice == nil && currentController?.haptics == nil {
            setupDirectHID()
        }
        if let dev = directHIDDevice {
            playDirectHIDPreset(preset, device: dev)
            return
        }
        
        // 2. Apple GameController CoreHaptics pathway
        guard let controller = currentController, controller.haptics != nil else {
            statusMessage = "Simulated haptic: \(preset.rawValue)"
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                self?.isVibrating = false
            }
            return
        }
        
        do {
            if engine == nil {
                setupEngine()
            }
            guard let engine = engine else {
                isVibrating = false
                return
            }
            try engine.start()
            
            let pattern = try createPattern(for: preset)
            activePlayer = try engine.makePlayer(with: pattern)
            try activePlayer?.start(atTime: CHHapticTimeImmediate)
            statusMessage = "Playing \(preset.rawValue) via CoreHaptics"
            
            let duration: Double = {
                switch preset {
                case .quickTap: return 0.2
                case .doubleTap: return 0.4
                case .heartbeat: return 0.6
                case .heavyImpact: return 0.5
                case .weaponBurst: return 0.7
                case .continuous: return 1.5
                }
            }()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
                self?.isVibrating = false
            }
        } catch {
            statusMessage = "Playback error: \(error.localizedDescription)"
            isVibrating = false
        }
    }
    
    public func startContinuousRumble() {
        isVibrating = true
        
        // Direct HID pathway
        if directHIDDevice == nil && currentController?.haptics == nil {
            setupDirectHID()
        }
        if let dev = directHIDDevice {
            sendDirectRumble(intensity: intensity, device: dev)
            statusMessage = "Direct USB continuous rumble active"
            return
        }
        
        guard let controller = currentController, controller.haptics != nil else {
            statusMessage = "Simulated continuous rumble active"
            return
        }
        
        do {
            if engine == nil {
                setupEngine()
            }
            guard let engine = engine else {
                isVibrating = false
                return
            }
            try engine.start()
            
            let intensityParam = CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity)
            let sharpnessParam = CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
            let event = CHHapticEvent(eventType: .hapticContinuous, parameters: [intensityParam, sharpnessParam], relativeTime: 0, duration: 30.0)
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            
            let player = try engine.makeAdvancedPlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
            self.continuousPlayer = player
            statusMessage = "Continuous CoreHaptics rumble playing"
        } catch {
            statusMessage = "Continuous error: \(error.localizedDescription)"
            isVibrating = false
        }
    }
    
    public func stopHaptics() {
        isVibrating = false
        
        if let dev = directHIDDevice {
            sendDirectRumble(intensity: 0, device: dev)
        }
        
        try? continuousPlayer?.stop(atTime: CHHapticTimeImmediate)
        try? activePlayer?.stop(atTime: CHHapticTimeImmediate)
        continuousPlayer = nil
        activePlayer = nil
        statusMessage = "Haptics stopped"
    }
    
    // MARK: - Direct Native macOS USB HID Force-Feedback (Unified Whole-Controller Vibration)
    
    private func setupDirectHID() {
        if hidManager == nil {
            let mgr = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
            let matchDict = [
                kIOHIDVendorIDKey as String: 0x2dc8
            ] as CFDictionary
            IOHIDManagerSetDeviceMatching(mgr, matchDict)
            _ = IOHIDManagerOpen(mgr, IOOptionBits(kIOHIDOptionsTypeNone))
            self.hidManager = mgr
        }
        
        if let mgr = hidManager,
           let deviceSet = IOHIDManagerCopyDevices(mgr) as? Set<IOHIDDevice>,
           let dev = deviceSet.first {
            _ = IOHIDDeviceOpen(dev, IOOptionBits(kIOHIDOptionsTypeNone))
            self.directHIDDevice = dev
            self.isDirectHIDActive = true
            self.statusMessage = "Direct macOS USB Force-Feedback Active (Report ID 5)"
        }
    }
    
    private func sendDirectRumble(intensity: Float, device: IOHIDDevice) {
        let val = UInt8(max(0, min(100, intensity * 100)))
        // Unified output report: sets all motor channels together for the whole controller
        var report: [UInt8] = [val, val, val, val]
        let res = IOHIDDeviceSetReport(device, kIOHIDReportTypeOutput, 5, &report, report.count)
        if res != kIOReturnSuccess {
            _ = IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone))
            _ = IOHIDDeviceSetReport(device, kIOHIDReportTypeOutput, 5, &report, report.count)
        }
    }
    
    private func playDirectHIDPreset(_ preset: HapticPresetPattern, device: IOHIDDevice) {
        statusMessage = "Playing \(preset.rawValue) (Unified Rumble)"
        
        switch preset {
        case .quickTap:
            sendDirectRumble(intensity: intensity, device: device)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                guard let self = self else { return }
                self.sendDirectRumble(intensity: 0, device: device)
                self.isVibrating = false
            }
            
        case .doubleTap:
            sendDirectRumble(intensity: intensity, device: device)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
                guard let self = self else { return }
                self.sendDirectRumble(intensity: 0, device: device)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
                    self.sendDirectRumble(intensity: self.intensity, device: device)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        self.sendDirectRumble(intensity: 0, device: device)
                        self.isVibrating = false
                    }
                }
            }
            
        case .heartbeat:
            sendDirectRumble(intensity: intensity, device: device)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { [weak self] in
                guard let self = self else { return }
                self.sendDirectRumble(intensity: 0, device: device)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    self.sendDirectRumble(intensity: self.intensity * 0.7, device: device)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        self.sendDirectRumble(intensity: 0, device: device)
                        self.isVibrating = false
                    }
                }
            }
            
        case .heavyImpact:
            sendDirectRumble(intensity: 1.0, device: device)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                guard let self = self else { return }
                self.sendDirectRumble(intensity: 0, device: device)
                self.isVibrating = false
            }
            
        case .weaponBurst:
            for i in 0..<4 {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.12) { [weak self] in
                    guard let self = self else { return }
                    self.sendDirectRumble(intensity: self.intensity, device: device)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                        self.sendDirectRumble(intensity: 0, device: device)
                        if i == 3 { self.isVibrating = false }
                    }
                }
            }
            
        case .continuous:
            sendDirectRumble(intensity: intensity, device: device)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                guard let self = self else { return }
                self.sendDirectRumble(intensity: 0, device: device)
                self.isVibrating = false
            }
        }
    }
    
    // MARK: - CoreHaptics Pattern Generator
    
    private func createPattern(for preset: HapticPresetPattern) throws -> CHHapticPattern {
        var events: [CHHapticEvent] = []
        let intParam = CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity)
        let shpParam = CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
        
        switch preset {
        case .quickTap:
            events.append(CHHapticEvent(eventType: .hapticTransient, parameters: [intParam, shpParam], relativeTime: 0))
            
        case .doubleTap:
            events.append(CHHapticEvent(eventType: .hapticTransient, parameters: [intParam, shpParam], relativeTime: 0))
            events.append(CHHapticEvent(eventType: .hapticTransient, parameters: [intParam, shpParam], relativeTime: 0.15))
            
        case .heartbeat:
            let lowSharp = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2)
            let highInt = CHHapticEventParameter(parameterID: .hapticIntensity, value: min(1.0, intensity * 1.1))
            events.append(CHHapticEvent(eventType: .hapticTransient, parameters: [highInt, lowSharp], relativeTime: 0))
            events.append(CHHapticEvent(eventType: .hapticTransient, parameters: [intParam, lowSharp], relativeTime: 0.2))
            
        case .heavyImpact:
            events.append(CHHapticEvent(eventType: .hapticContinuous, parameters: [intParam, shpParam], relativeTime: 0, duration: 0.35))
            
        case .weaponBurst:
            for i in 0..<4 {
                events.append(CHHapticEvent(eventType: .hapticTransient, parameters: [intParam, shpParam], relativeTime: Double(i) * 0.1))
            }
            
        case .continuous:
            events.append(CHHapticEvent(eventType: .hapticContinuous, parameters: [intParam, shpParam], relativeTime: 0, duration: 1.5))
        }
        
        return try CHHapticPattern(events: events, parameters: [])
    }
}
