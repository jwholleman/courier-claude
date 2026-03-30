import AppKit
import ApplicationServices
import Carbon

/// Manages Accessibility permission checks and Secure Event Input monitoring.
enum AccessibilityPermission {

    /// Returns true if the app has Accessibility permission.
    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// Prompts the user for Accessibility permission if not already granted.
    static func requestIfNeeded() {
        guard !isTrusted else { return }
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [promptKey: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    /// Returns true if another app has enabled Secure Event Input,
    /// which can prevent Carbon global hotkeys from firing.
    static var isSecureInputActive: Bool {
        IsSecureEventInputEnabled()
    }

    /// Opens the Accessibility section of System Settings.
    static func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
