import AppKit
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let toggleCourier = Self("toggleCourier")
}

final class AppDelegate: NSObject, NSApplicationDelegate {

    // Strong references — keep window controller and panel alive for app lifetime.
    var windowController: LauncherWindowController?

    private let hotKeyProvider: HotKeyProvider = KeyboardShortcutsProvider()
    private var activityToken: NSObjectProtocol?
    private var accessibilityTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Single-instance guard
        let bundleID = Bundle.main.bundleIdentifier ?? ""
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        if running.count > 1 {
            running.first(where: { $0 != .current })?.activate()
            NSApp.terminate(nil)
            return
        }

        // Prevent App Nap — critical for hotkey responsiveness after idle
        activityToken = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiated, .idleSystemSleepDisabled],
            reason: "Listening for global hotkey"
        )

        // Create and retain the window controller (panel + view model pre-created at launch)
        windowController = LauncherWindowController()

        // Register global hotkey via provider
        hotKeyProvider.register { [weak self] in
            Task { @MainActor in
                self?.windowController?.toggle()
            }
        }

        // Accessibility permission check — prompt on first launch
        AccessibilityPermission.requestIfNeeded()

        // Start periodic monitoring (60s interval)
        startMonitoringTimer()

        // Also check on wake from sleep — sleep/wake can reset trust state
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        accessibilityTimer?.invalidate()
    }

    // MARK: - Panel

    func togglePanel() {
        Task { @MainActor in
            windowController?.toggle()
        }
    }

    func openSettings() {
        // Settings window implemented in Phase 6
    }

    // MARK: - Permission Monitoring

    private func startMonitoringTimer() {
        accessibilityTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.checkPermissions()
        }
    }

    @objc private func didWake() {
        checkPermissions()
    }

    private func checkPermissions() {
        if !AccessibilityPermission.isTrusted {
            NotificationHelper.postAccessibilityRevoked()
        }
        if AccessibilityPermission.isSecureInputActive {
            NotificationHelper.postSecureInputActive()
        }
    }
}
