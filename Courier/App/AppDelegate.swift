import AppKit
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let toggleCourier = Self("toggleCourier")
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    // Strong references — keep window controller and panel alive for app lifetime.
    var windowController: LauncherWindowController?
    private var wizardController: SetupWizardWindowController?
    private var settingsController: SettingsWindowController?
    private var statusItem: NSStatusItem?

    private let hotKeyProvider: HotKeyProvider = KeyboardShortcutsProvider()
    private var activityToken: NSObjectProtocol?
    private var accessibilityTimer: Timer?
    private var lastAccessibilityTrusted = AccessibilityPermission.isTrusted
    private var lastSecureInputState = AccessibilityPermission.isSecureInputActive

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

        // Apply saved theme before any windows appear
        windowController?.viewModel.settings?.applyTheme()

        // Check if previous session crashed mid-dispatch and inform user
        windowController?.checkCrashRecovery()

        // Register global hotkey via provider
        hotKeyProvider.register { [weak self] in
            Task { @MainActor in
                self?.windowController?.toggle()
            }
        }

        // Request notification authorization — required for toasts to appear
        NotificationHelper.requestAuthorization()

        // Sync login item in case system state was lost (e.g. app replaced in /Applications)
        let settings = windowController?.viewModel.settings
        LoginItemManager.shared.syncIfNeeded(userIntent: settings?.launchAtLogin ?? false)

        // Show setup wizard on first launch
        if !(settings?.hasCompletedSetup ?? false) {
            showSetupWizard()
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

        checkPermissions(notifyOnChangeOnly: false)

        setupStatusItem()
    }

    func applicationWillTerminate(_ notification: Notification) {
        accessibilityTimer?.invalidate()
    }

    // MARK: - Status Item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            let image = NSImage(named: "MenuBarIcon")!
            image.size = NSSize(width: 18, height: 18)
            image.isTemplate = true
            button.image = image
            button.setAccessibilityLabel("Courier")
        }

        let menu = NSMenu()

        let showItem = NSMenuItem(title: "Show Courier", action: #selector(handleTogglePanel), keyEquivalent: "")
        showItem.target = self
        menu.addItem(showItem)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(handleOpenSettings), keyEquivalent: ",")
        settingsItem.keyEquivalentModifierMask = .command
        settingsItem.target = self
        menu.addItem(settingsItem)

        let aboutItem = NSMenuItem(title: "About Courier", action: #selector(handleAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        let helpItem = NSMenuItem(title: "Help", action: #selector(handleHelp), keyEquivalent: "")
        helpItem.target = self
        menu.addItem(helpItem)

        menu.addItem(.separator())

        let updatesItem = NSMenuItem(title: "Check for Updates...", action: nil, keyEquivalent: "")
        updatesItem.isEnabled = false
        menu.addItem(updatesItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit Courier", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quitItem.keyEquivalentModifierMask = .command
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    @objc private func handleTogglePanel() { togglePanel() }
    @objc private func handleOpenSettings() { openSettings() }

    @objc private func handleAbout() {
        NSApp.activate(ignoringOtherApps: true)
        var options: [NSApplication.AboutPanelOptionKey: Any] = [
            .applicationVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0",
            .credits: NSAttributedString(
                string: "A universal query launcher for macOS.",
                attributes: [.font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)]
            )
        ]
        if let icon = NSImage(named: "AppIcon") {
            options[.applicationIcon] = icon
        }
        NSApp.orderFrontStandardAboutPanel(options: options)
    }

    @objc private func handleHelp() {
        if let url = URL(string: "https://github.com/jwholleman/courier") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Panel

    func togglePanel() {
        Task { @MainActor in
            windowController?.toggle()
        }
    }

    func openSettings() {
        let settings = windowController?.viewModel.settings ?? AppSettings()
        if settingsController == nil {
            settingsController = SettingsWindowController(settings: settings)
        }
        settingsController?.show()
    }

    func showSetupWizard() {
        let settings = windowController?.viewModel.settings ?? AppSettings()
        if wizardController == nil {
            wizardController = SetupWizardWindowController(settings: settings)
        }
        wizardController?.show()
    }

    // MARK: - Permission Monitoring

    private func startMonitoringTimer() {
        accessibilityTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkPermissions()
            }
        }
    }

    @objc private func didWake() {
        Task { @MainActor in
            reRegisterHotKeyIfNeeded()
            checkPermissions(notifyOnChangeOnly: false)
        }
    }

    private func checkPermissions(notifyOnChangeOnly: Bool = true) {
        let isTrusted = AccessibilityPermission.isTrusted
        let isSecureInputActive = AccessibilityPermission.isSecureInputActive

        if !isTrusted && (!notifyOnChangeOnly || lastAccessibilityTrusted != isTrusted) {
            Task { @MainActor in await NotificationHelper.postAccessibilityRevoked() }
        }

        if isSecureInputActive && (!notifyOnChangeOnly || lastSecureInputState != isSecureInputActive) {
            Task { @MainActor in await NotificationHelper.postSecureInputActive() }
        }

        lastAccessibilityTrusted = isTrusted
        lastSecureInputState = isSecureInputActive
    }

    private func reRegisterHotKeyIfNeeded() {
        if let shortcut = KeyboardShortcuts.getShortcut(for: .toggleCourier) {
            KeyboardShortcuts.setShortcut(shortcut, for: .toggleCourier)
        } else {
            hotKeyProvider.register { [weak self] in
                Task { @MainActor in
                    self?.windowController?.toggle()
                }
            }
        }
    }
}
