import AppKit

/// Handles system notifications and toast messages for permission and error states.
/// Full implementation in Phase 3.
enum NotificationHelper {

    static func postAccessibilityRevoked() {
        // Phase 3: System notification "Courier needs Accessibility access."
        // with action to open x-apple.systempreferences:...Privacy_Accessibility
    }

    static func postSecureInputActive() {
        // Phase 3: Toast "A secure input app may be blocking Courier's hotkey."
    }
}
