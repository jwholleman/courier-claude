import AppKit
import UserNotifications

/// Delivers in-app toast messages and system-level notifications.
enum NotificationHelper {

    // MARK: - Toast (in-process, menu-bar popover style)

    /// Shows a brief toast via NSUserNotificationCenter-style alert.
    /// Falls back gracefully if notification permission is not granted.
    @MainActor
    static func showToast(_ message: String) async {
        let content = UNMutableNotificationContent()
        content.title = "Courier"
        content.body = message
        content.sound = nil

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        let center = UNUserNotificationCenter.current()
        try? await center.add(request)
    }

    // MARK: - Permission prompts

    /// Posts a notification prompting the user to restore Accessibility access.
    @MainActor
    static func postAccessibilityRevoked() async {
        await showToast("Courier needs Accessibility access. Open System Settings → Privacy & Security → Accessibility.")
    }

    /// Posts a notification prompting the user to grant Automation access for a specific app.
    @MainActor
    static func postAutomationDenied(appName: String) async {
        await showToast("Courier needs permission to control \(appName). Open System Settings → Privacy & Security → Automation.")
    }

    /// Posts a notification warning about Secure Input blocking the hotkey.
    @MainActor
    static func postSecureInputActive() async {
        await showToast("A secure input field may be blocking Courier's hotkey. Try dismissing password prompts first.")
    }

    // MARK: - Notification authorization

    /// Requests authorization to show notifications (call once at launch).
    static func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { _, _ in }
    }
}
