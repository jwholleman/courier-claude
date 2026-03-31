import AppKit
import UserNotifications

/// Handles in-app toasts (ToastPanel) and system notifications (UNUserNotificationCenter).
enum NotificationHelper {

    // MARK: - Shared toast panel (pre-created, reused)

    static let toastPanel = ToastPanel()

    // MARK: - Toast (transient, no permission required)

    @MainActor
    static func showToast(_ message: String) async {
        let screen = NSScreen.main
        toastPanel.show(message, on: screen)
    }

    // MARK: - System notifications (persists in Notification Center, requires permission)

    @MainActor
    static func postAccessibilityRevoked() async {
        await postSystemNotification(
            title: "Accessibility Access Required",
            body: "Courier needs Accessibility access to paste queries. Click to open System Settings."
        )
    }

    @MainActor
    static func postAutomationDenied(appName: String) async {
        await postSystemNotification(
            title: "Automation Permission Required",
            body: "Courier needs permission to control \(appName). Open System Settings → Privacy & Security → Automation."
        )
    }

    @MainActor
    static func postSecureInputActive() async {
        await showToast("A secure input field may be blocking Courier's hotkey.")
    }

    // MARK: - Authorization

    static func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { _, _ in }
    }

    // MARK: - Private

    @MainActor
    private static func postSystemNotification(title: String, body: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = nil
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }
}
