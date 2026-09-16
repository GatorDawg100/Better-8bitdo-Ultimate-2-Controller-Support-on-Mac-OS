import Foundation
import Combine
import EightBitDoKit

/// Main coordinator service that bridges 8BitDo hardware input to virtual DualSense 5 output.
@MainActor
public final class DualSenseEmulator: ObservableObject {
    public static let shared = DualSenseEmulator()
    
    // Published State
    @Published public private(set) var isEmulating: Bool = false
    @Published public var activeProfile: RemappingProfile = .standard
    @Published public var savedProfiles: [RemappingProfile] = RemappingProfile.defaultPresets
    
    @Published public private(set) var packetRateHz: Double = 0.0
    @Published public private(set) var totalPacketsSent: UInt64 = 0
    @Published public private(set) var lastErrorMessage: String?
    
    @Published public private(set) var isAccessibilityGranted: Bool = false
    @Published public private(set) var isInputMonitoringGranted: Bool = false
    
    // Core Components
    private let virtualDevice = DualSenseVirtualDevice()
    private var packer = DualSenseReportPacker()
    private let eightBitDo = EightBitDoDevice.shared
    
    private var cancellables = Set<AnyCancellable>()
    private var ratePacketCount: UInt64 = 0
    private var lastRateCalcTime: TimeInterval = 0
    private let queue = DispatchQueue(label: "com.deencodes.ds5.emulator.pipeline", qos: .userInteractive)
    
    public init() {
        checkPermissions()
        loadPersistedProfiles()
        
        // Link rumble feedback from virtual DualSense to 8BitDo physical rumble motors
        Task { [weak self] in
            await self?.virtualDevice.setRumbleHandler { [weak self] lowFreq, highFreq in
                Task { @MainActor [weak self] in
                    guard let self = self, self.isEmulating else { return }
                    let mult = self.activeProfile.rumbleMultiplier
                    self.eightBitDo.sendRumble(lowFrequency: lowFreq * mult, highFrequency: highFreq * mult)
                }
            }
        }
        
        // Listen to 8BitDo reports
        eightBitDo.onStateChanged = { [weak self] state in
            Task { @MainActor [weak self] in
                guard let self = self, self.isEmulating else { return }
                self.processState(state)
            }
        }
    }
    
    public func checkPermissions() {
        isAccessibilityGranted = PermissionHelper.isAccessibilityGranted()
        isInputMonitoringGranted = PermissionHelper.isInputMonitoringGranted()
    }
    
    public func startEmulation() {
        checkPermissions()
        guard isAccessibilityGranted else {
            lastErrorMessage = "Accessibility permission is required to create a virtual controller. Please click 'Grant Accessibility' below."
            PermissionHelper.requestAccessibility()
            return
        }
        
        Task {
            do {
                try await virtualDevice.start()
                isEmulating = true
                lastErrorMessage = nil
                eightBitDo.start()
                print("[DualSenseEmulator] Emulation successfully started")
            } catch {
                lastErrorMessage = error.localizedDescription
                isEmulating = false
                print("[DualSenseEmulator] Failed to start emulation: \(error)")
            }
        }
    }
    
    public func stopEmulation() {
        Task {
            await virtualDevice.stop()
        }
        isEmulating = false
        eightBitDo.stopRumble()
        packetRateHz = 0.0
        print("[DualSenseEmulator] Emulation stopped")
    }
    
    public func toggleEmulation() {
        if isEmulating {
            stopEmulation()
        } else {
            startEmulation()
        }
    }
    
    public func setProfile(_ profile: RemappingProfile) {
        activeProfile = profile
        saveCurrentProfileSelection()
    }
    
    public func saveProfile(_ profile: RemappingProfile) {
        if let idx = savedProfiles.firstIndex(where: { $0.id == profile.id }) {
            savedProfiles[idx] = profile
        } else {
            savedProfiles.append(profile)
        }
        if activeProfile.id == profile.id {
            activeProfile = profile
        }
        persistProfiles()
    }
    
    // MARK: - Pipeline Processing
    
    private func processState(_ state: EightBitDoState) {
        let reportData = packer.pack(state: state, profile: activeProfile)
        
        Task { [weak self] in
            guard let self = self else { return }
            do {
                try await self.virtualDevice.dispatchReport(data: reportData)
                await MainActor.run {
                    self.totalPacketsSent += 1
                    self.ratePacketCount += 1
                    
                    let now = ProcessInfo.processInfo.systemUptime
                    if now - self.lastRateCalcTime >= 1.0 {
                        let elapsed = now - self.lastRateCalcTime
                        self.packetRateHz = Double(self.ratePacketCount) / elapsed
                        self.lastRateCalcTime = now
                        self.ratePacketCount = 0
                    }
                }
            } catch {
                await MainActor.run {
                    self.lastErrorMessage = error.localizedDescription
                }
            }
        }
    }
    
    // MARK: - Persistence
    
    private func persistProfiles() {
        if let data = try? JSONEncoder().encode(savedProfiles) {
            UserDefaults.standard.set(data, forKey: "saved_controller_profiles")
        }
    }
    
    private func saveCurrentProfileSelection() {
        UserDefaults.standard.set(activeProfile.id.uuidString, forKey: "active_controller_profile_id")
    }
    
    private func loadPersistedProfiles() {
        if let data = UserDefaults.standard.data(forKey: "saved_controller_profiles"),
           let loaded = try? JSONDecoder().decode([RemappingProfile].self, from: data),
           !loaded.isEmpty {
            self.savedProfiles = loaded
        }
        
        if let activeIdStr = UserDefaults.standard.string(forKey: "active_controller_profile_id"),
           let uuid = UUID(uuidString: activeIdStr),
           let match = savedProfiles.first(where: { $0.id == uuid }) {
            self.activeProfile = match
        } else if let first = savedProfiles.first {
            self.activeProfile = first
        }
    }
}
