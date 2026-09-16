import Foundation
import AppKit
import Combine
import EightBitDoKit
import DualSenseEmulationKit

/// Manages the macOS system menu bar icon for background DualSense emulation and quick controls.
@MainActor
public final class MenuBarManager: NSObject {
    public static let shared = MenuBarManager()
    
    private var statusItem: NSStatusItem?
    private var cancellables = Set<AnyCancellable>()
    private weak var window: NSWindow?
    
    public override init() {
        super.init()
    }
    
    public func setup(window: NSWindow? = nil) {
        if let window = window {
            self.window = window
        }
        
        guard statusItem == nil else { return }
        
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "gamecontroller.fill", accessibilityDescription: "8BitDo DS5 Controller")
            button.imagePosition = .imageLeft
        }
        
        self.statusItem = item
        updateMenu()
        
        // Listen to emulator changes
        DualSenseEmulator.shared.$isEmulating
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateMenu()
            }
            .store(in: &cancellables)
            
        DualSenseEmulator.shared.$packetRateHz
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateMenu()
            }
            .store(in: &cancellables)
            
        EightBitDoDevice.shared.$isConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateMenu()
            }
            .store(in: &cancellables)
    }
    
    public func setWindow(_ window: NSWindow) {
        self.window = window
    }
    
    public func updateMenu() {
        let menu = NSMenu()
        
        // 1. Device Status
        let isConnected = EightBitDoDevice.shared.isConnected
        let deviceItem = NSMenuItem(
            title: isConnected ? "● 8BitDo Ultimate 2: Connected (D-Input)" : "○ 8BitDo Ultimate 2: Disconnected",
            action: nil,
            keyEquivalent: ""
        )
        deviceItem.isEnabled = false
        menu.addItem(deviceItem)
        
        // 2. Emulation Status
        let isEmulating = DualSenseEmulator.shared.isEmulating
        let hz = Int(DualSenseEmulator.shared.packetRateHz)
        let emuTitle = isEmulating ? "● DS5 Emulation: Active (\(hz) Hz)" : "○ DS5 Emulation: Inactive"
        let emuStatusItem = NSMenuItem(title: emuTitle, action: nil, keyEquivalent: "")
        emuStatusItem.isEnabled = false
        menu.addItem(emuStatusItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 3. Emulation Toggle Button
        let toggleItem = NSMenuItem(
            title: isEmulating ? "Stop DS5 Emulation" : "Start DS5 Emulation",
            action: #selector(toggleEmulationAction),
            keyEquivalent: "e"
        )
        toggleItem.target = self
        menu.addItem(toggleItem)
        
        // 4. Active Profile Submenu
        let profileSubmenu = NSMenu()
        let activeProfile = DualSenseEmulator.shared.activeProfile
        for profile in DualSenseEmulator.shared.savedProfiles {
            let item = NSMenuItem(title: profile.name, action: #selector(selectProfileAction(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = profile
            if profile.id == activeProfile.id {
                item.state = .on
            }
            profileSubmenu.addItem(item)
        }
        let profileMenuItem = NSMenuItem(title: "Profile: \(activeProfile.name)", action: nil, keyEquivalent: "")
        profileMenuItem.submenu = profileSubmenu
        menu.addItem(profileMenuItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 5. Open Window
        let showWindowItem = NSMenuItem(
            title: "Open Controller Tester & Remapper...",
            action: #selector(showMainWindowAction),
            keyEquivalent: "o"
        )
        showWindowItem.target = self
        menu.addItem(showWindowItem)
        
        // 6. Run in Background Toggle
        let runInBackground = UserDefaults.standard.object(forKey: "run_in_background") as? Bool ?? true
        let bgItem = NSMenuItem(
            title: "Keep Running in Background on Close",
            action: #selector(toggleBackgroundModeAction),
            keyEquivalent: ""
        )
        bgItem.target = self
        bgItem.state = runInBackground ? .on : .off
        menu.addItem(bgItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 7. Quit
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitAction), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
        
        // Update menu bar title badge
        if let button = statusItem?.button {
            button.title = isEmulating ? " DS5" : ""
        }
    }
    
    @objc private func toggleEmulationAction() {
        DualSenseEmulator.shared.toggleEmulation()
    }
    
    @objc private func selectProfileAction(_ sender: NSMenuItem) {
        if let profile = sender.representedObject as? RemappingProfile {
            DualSenseEmulator.shared.setProfile(profile)
            updateMenu()
        }
    }
    
    @objc private func showMainWindowAction() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        if let win = window ?? NSApplication.shared.windows.first {
            win.makeKeyAndOrderFront(nil)
            win.orderFrontRegardless()
        }
    }
    
    @objc private func toggleBackgroundModeAction() {
        let current = UserDefaults.standard.object(forKey: "run_in_background") as? Bool ?? true
        UserDefaults.standard.set(!current, forKey: "run_in_background")
        updateMenu()
    }
    
    @objc private func quitAction() {
        DualSenseEmulator.shared.stopEmulation()
        NSApplication.shared.terminate(nil)
    }
}
