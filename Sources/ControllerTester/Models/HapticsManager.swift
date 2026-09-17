import Foundation
import CoreHaptics
import GameController
import SwiftUI
import Combine
import EightBitDoKit

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
    private weak var currentController: GCController?
    private var cancellables = Set<AnyCancellable>()
    
    public init() {
        self.isDirectHIDActive = EightBitDoDevice.shared.isConnected
        EightBitDoDevice.shared.$isConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] connected in
                guard let self = self else { return }
                self.isDirectHIDActive = connected
                if connected {
                    self.statusMessage = "Direct Force-Feedback Active"
                }
            }
            .store(in: &cancellables)
    }
    
    public func setController(_ controller: GCController?) {
        self.currentController = controller
        stopHaptics()
        
        if let controller = controller, controller.haptics != nil {
            setupEngine()
            statusMessage = "Ready (\(controller.vendorName ?? "Controller"))"
            self.isDirectHIDActive = EightBitDoDevice.shared.isConnected
        } else if EightBitDoDevice.shared.isConnected {
            self.isDirectHIDActive = true
            statusMessage = "Direct Force-Feedback Active"
        } else {
            self.isDirectHIDActive = false
            self.engine = nil
            statusMessage = controller != nil ? "Ready" : "Simulation Mode"
        }
    }
    
    public func setupEngine() {
        guard let controller = currentController, let haptics = controller.haptics else {
            engine = nil
            return
        }
        
        do {
            let localityToUse: GCHapticsLocality = haptics.supportedLocalities.contains(.all) ? .all : .default
            guard let newEngine = haptics.createEngine(withLocality: localityToUse) else {
                statusMessage = "Unable to create haptic engine"
                return
            }
            
            newEngine.resetHandler = { [weak self] in
                try? self?.engine?.start()
            }
            newEngine.stoppedHandler = { [weak self] _ in
                try? self?.engine?.start()
            }
            
            engine = newEngine
            try engine?.start()
            statusMessage = "Apple CoreHaptics active"
        } catch {
            statusMessage = "CoreHaptics init: \(error.localizedDescription)"
        }
    }
    
    public func playPreset(_ preset: HapticPresetPattern) {
        isVibrating = true
        statusMessage = "Playing \(preset.rawValue)..."
        
        // 1. Direct native EightBitDoKit driver rumble
        if EightBitDoDevice.shared.isConnected {
            playDirectHIDPreset(preset)
        }
        
        // 2. Apple GameController CoreHaptics pathway (e.g. DualSense)
        playCoreHapticsPreset(preset)
    }
    
    public func startContinuousRumble() {
        isVibrating = true
        statusMessage = "Continuous rumble active"
        
        if EightBitDoDevice.shared.isConnected {
            EightBitDoDevice.shared.sendRumble(lowFrequency: intensity, highFrequency: sharpness)
        }
        
        // Apple CoreHaptics
        if let controller = currentController, controller.haptics != nil {
            do {
                if engine == nil { setupEngine() }
                if let engine = engine {
                    try engine.start()
                    let intParam = CHHapticEventParameter(parameterID: .hapticIntensity, value: max(0.2, intensity))
                    let shpParam = CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
                    let event = CHHapticEvent(eventType: .hapticContinuous, parameters: [intParam, shpParam], relativeTime: 0, duration: 30.0)
                    let pattern = try CHHapticPattern(events: [event], parameters: [])
                    let player = try engine.makePlayer(with: pattern)
                    try player.start(atTime: CHHapticTimeImmediate)
                    self.activePlayer = player
                }
            } catch {
                // Ignore CoreHaptics error when direct HID is active
            }
        }
    }
    
    public func stopHaptics() {
        isVibrating = false
        EightBitDoDevice.shared.stopRumble()
        try? activePlayer?.stop(atTime: CHHapticTimeImmediate)
        activePlayer = nil
        statusMessage = "Haptics stopped"
    }
    
    // MARK: - Direct Native EightBitDo Preset Sequencer
    
    private func playDirectHIDPreset(_ preset: HapticPresetPattern) {
        switch preset {
        case .quickTap:
            EightBitDoDevice.shared.sendRumble(lowFrequency: intensity, highFrequency: sharpness)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                EightBitDoDevice.shared.stopRumble()
                self?.isVibrating = false
            }
            
        case .doubleTap:
            EightBitDoDevice.shared.sendRumble(lowFrequency: intensity, highFrequency: sharpness)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
                EightBitDoDevice.shared.stopRumble()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) { [weak self] in
                    guard let self = self else { return }
                    EightBitDoDevice.shared.sendRumble(lowFrequency: self.intensity, highFrequency: self.sharpness)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                        EightBitDoDevice.shared.stopRumble()
                        self?.isVibrating = false
                    }
                }
            }
            
        case .heartbeat:
            EightBitDoDevice.shared.sendRumble(lowFrequency: intensity, highFrequency: sharpness)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { [weak self] in
                EightBitDoDevice.shared.stopRumble()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
                    guard let self = self else { return }
                    EightBitDoDevice.shared.sendRumble(lowFrequency: self.intensity * 0.7, highFrequency: self.sharpness * 0.5)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                        EightBitDoDevice.shared.stopRumble()
                        self?.isVibrating = false
                    }
                }
            }
            
        case .heavyImpact:
            EightBitDoDevice.shared.sendRumble(lowFrequency: 1.0, highFrequency: 1.0)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                EightBitDoDevice.shared.stopRumble()
                self?.isVibrating = false
            }
            
        case .weaponBurst:
            for i in 0..<4 {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.12) { [weak self] in
                    guard let self = self else { return }
                    EightBitDoDevice.shared.sendRumble(lowFrequency: self.intensity, highFrequency: self.sharpness)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) { [weak self] in
                        EightBitDoDevice.shared.stopRumble()
                        if i == 3 { self?.isVibrating = false }
                    }
                }
            }
            
        case .continuous:
            EightBitDoDevice.shared.sendRumble(lowFrequency: intensity, highFrequency: sharpness)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                EightBitDoDevice.shared.stopRumble()
                self?.isVibrating = false
            }
        }
    }
    
    // MARK: - CoreHaptics Pattern Generator (ERM Continuous Events)
    
    private func playCoreHapticsPreset(_ preset: HapticPresetPattern) {
        guard let controller = currentController, controller.haptics != nil else { return }
        
        do {
            if engine == nil { setupEngine() }
            guard let engine = engine else { return }
            try engine.start()
            
            let pattern = try createPattern(for: preset)
            activePlayer = try engine.makePlayer(with: pattern)
            try activePlayer?.start(atTime: CHHapticTimeImmediate)
        } catch {
            // CoreHaptics fallback handled by direct HID
        }
    }
    
    private func createPattern(for preset: HapticPresetPattern) throws -> CHHapticPattern {
        var events: [CHHapticEvent] = []
        let intParam = CHHapticEventParameter(parameterID: .hapticIntensity, value: max(0.2, intensity))
        let shpParam = CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
        
        switch preset {
        case .quickTap:
            events.append(CHHapticEvent(eventType: .hapticContinuous, parameters: [intParam, shpParam], relativeTime: 0, duration: 0.14))
            
        case .doubleTap:
            events.append(CHHapticEvent(eventType: .hapticContinuous, parameters: [intParam, shpParam], relativeTime: 0, duration: 0.09))
            events.append(CHHapticEvent(eventType: .hapticContinuous, parameters: [intParam, shpParam], relativeTime: 0.16, duration: 0.09))
            
        case .heartbeat:
            let lowSharp = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2)
            let highInt = CHHapticEventParameter(parameterID: .hapticIntensity, value: min(1.0, intensity * 1.1))
            events.append(CHHapticEvent(eventType: .hapticContinuous, parameters: [highInt, lowSharp], relativeTime: 0, duration: 0.14))
            events.append(CHHapticEvent(eventType: .hapticContinuous, parameters: [intParam, lowSharp], relativeTime: 0.22, duration: 0.18))
            
        case .heavyImpact:
            let maxInt = CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0)
            events.append(CHHapticEvent(eventType: .hapticContinuous, parameters: [maxInt, shpParam], relativeTime: 0, duration: 0.40))
            
        case .weaponBurst:
            for i in 0..<4 {
                events.append(CHHapticEvent(eventType: .hapticContinuous, parameters: [intParam, shpParam], relativeTime: Double(i) * 0.12, duration: 0.07))
            }
            
        case .continuous:
            events.append(CHHapticEvent(eventType: .hapticContinuous, parameters: [intParam, shpParam], relativeTime: 0, duration: 2.0))
        }
        
        return try CHHapticPattern(events: events, parameters: [])
    }
}
