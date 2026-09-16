import Foundation
import ApplicationServices
import IOKit
import IOKit.hid
import AppKit

/// Utility to check, prompt, and manage macOS Accessibility and Input Monitoring permissions.
public enum PermissionHelper {
    
    /// Checks whether the application has Accessibility permissions (needed for virtual HID device registration).
    public static func isAccessibilityGranted() -> Bool {
        AXIsProcessTrusted()
    }
    
    /// Prompts the macOS system alert asking the user to grant Accessibility permissions to this app.
    public static func requestAccessibility() {
        let key = "AXTrustedCheckOptionPrompt" as CFString
        let options = [key: kCFBooleanTrue] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
    
    /// Checks whether Input Monitoring permission is granted.
    public static func isInputMonitoringGranted() -> Bool {
        IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted
    }
    
    /// Requests Input Monitoring permission from the user.
    public static func requestInputMonitoring() {
        _ = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
    }
    
    /// Opens the exact macOS System Settings Privacy & Security panel.
    public static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
    
    public static func openInputMonitoringSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
    }
}
