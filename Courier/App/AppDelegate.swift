import AppKit
import Carbon
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let toggleCourier = Self("toggleCourier")
}

final class AppDelegate: NSObject, NSApplicationDelegate {

    // Strong references — keep window controller and panel alive for app lifetime.
    // Populated in applicationDidFinishLaunching; nil until then.
    var windowController: LauncherWindowController?

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

        // Create and retain the window controller (panel + view model pre-created)
        windowController = LauncherWindowController()

        // Register global hotkey (default: Option+Space)
        if KeyboardShortcuts.getShortcut(for: .toggleCourier) == nil {
            KeyboardShortcuts.setShortcut(.init(.space, modifiers: .option), for: .toggleCourier)
        }
        KeyboardShortcuts.onKeyUp(for: .toggleCourier) { [weak self] in
            Task { @MainActor in
                self?.windowController?.toggle()
            }
        }

        // Accessibility permission check — prompt on first launch
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [promptKey: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)

        // Start periodic monitoring (60s interval)
        startMonitoringTimer()

        // Check on wake from sleep
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

    // MARK: - Accessibility & Secure Input Monitoring

    private func startMonitoringTimer() {
        accessibilityTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.checkPermissions()
        }
    }

    @objc private func didWake() {
        checkPermissions()
    }

    private func checkPermissions() {
        if !AXIsProcessTrusted() {
            NotificationHelper.postAccessibilityRevoked()
        }
        if IsSecureEventInputEnabled() {
            NotificationHelper.postSecureInputActive()
        }
    }
}
