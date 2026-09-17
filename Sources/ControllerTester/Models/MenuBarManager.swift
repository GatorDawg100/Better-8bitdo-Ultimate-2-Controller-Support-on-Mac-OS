import Foundation
import AppKit
import Combine
import EightBitDoKit

/// Manages the macOS system menu bar icon for quick status and window controls.
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
            button.image = NSImage(systemSymbolName: "gamecontroller.fill", accessibilityDescription: "8BitDo Controller Tester")
            button.imagePosition = .imageLeft
        }
        
        self.statusItem = item
        updateMenu()
        
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
            title: isConnected ? "● 8BitDo Ultimate 2: Connected" : "○ 8BitDo Ultimate 2: Disconnected",
            action: nil,
            keyEquivalent: ""
        )
        deviceItem.isEnabled = false
        menu.addItem(deviceItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 2. Open Window
        let showWindowItem = NSMenuItem(
            title: "Open Controller Tester...",
            action: #selector(showMainWindowAction),
            keyEquivalent: "o"
        )
        showWindowItem.target = self
        menu.addItem(showWindowItem)
        
        // 3. Run in Background Toggle
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
        
        // 4. Quit
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitAction), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
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
        NSApplication.shared.terminate(nil)
    }
}
