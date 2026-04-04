import AppKit
import Foundation

/// Serial queue for all dispatch operations — prevents concurrent clipboard manipulation.
private let dispatchQueue = DispatchQueue(label: "com.courier.dispatch", qos: .userInitiated)

enum AppleScriptError: Error {
    case accessibilityDenied
    case automationDenied(appName: String)
    case appLaunchTimeout
    case pasteTimeout
    case scriptError(String)
}

enum AppleScriptHelper {

    // MARK: - Public entry point

    static func dispatch(
        query: String,
        bundleID: String,
        appURL: URL,
        serviceType: ServiceType,
        keystroke: LLMKeystroke? = nil,
        newChatURL: URL? = nil,
        browserFallback: @escaping () async throws -> Void
    ) async throws {
        print("[Courier] Attempting native dispatch to \(bundleID)")
        let resolvedKeystroke = keystroke ?? serviceType.newConversationKeystroke

        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                dispatchQueue.async {
                    do {
                        try dispatchSync(
                            query: query,
                            bundleID: bundleID,
                            appURL: appURL,
                            serviceType: serviceType,
                            keystroke: resolvedKeystroke,
                            newChatURL: newChatURL
                        )
                        continuation.resume()
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        } catch AppleScriptError.accessibilityDenied {
            print("[Courier] Accessibility denied — keystrokes blocked, falling back to browser")
            await showAccessibilityAlert()
            try await browserFallback()
        } catch AppleScriptError.automationDenied(let appName) {
            print("[Courier] Automation denied for \(appName)")
            await showAutomationAlert(appName: appName)
            try await browserFallback()
        } catch AppleScriptError.appLaunchTimeout {
            let appName = serviceType.displayName
            print("[Courier] App launch timeout for \(appName)")
            await NotificationHelper.showToast("'\(appName)' took too long to launch. Query copied to clipboard.")
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(query, forType: .string)
            try await browserFallback()
        } catch {
            let appName = serviceType.displayName
            print("[Courier] Dispatch error for \(appName): \(error)")
            await NotificationHelper.showToast("Couldn't paste into \(appName). Query copied to clipboard. Opening in browser.")
            try await browserFallback()
        }
    }

    // MARK: - Permission alerts

    @MainActor
    private static func showAccessibilityAlert() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Permission Needed"
        alert.informativeText = """
        Courier needs Accessibility access to send keystrokes.

        To fix this:
        1. Open System Settings → Privacy & Security → Accessibility
        2. Remove ALL existing "Courier" entries (select each and click –)
        3. Relaunch Courier — it will prompt you to add itself
        4. Enable the new entry

        This is a one-time setup. Development builds can leave stale entries that shadow the active one.
        """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open Accessibility Settings")
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        }
    }

    @MainActor
    private static func showAutomationAlert(appName: String) {
        let alert = NSAlert()
        alert.messageText = "Automation Permission Required"
        alert.informativeText = "Courier needs permission to control System Events to paste into apps.\n\nOpen System Settings → Privacy & Security → Automation, then enable \"System Events\" under Courier."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Use Browser Instead")
        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")!)
        }
    }

    // MARK: - Synchronous dispatch (runs on dispatchQueue)

    private static func dispatchSync(
        query: String,
        bundleID: String,
        appURL: URL,
        serviceType: ServiceType,
        keystroke: LLMKeystroke,
        newChatURL: URL? = nil
    ) throws {
        let pasteboard = NSPasteboard.general

        // Step 1 — Deep-copy clipboard (proxy items become invalid after modification)
        let savedClipboard = saveClipboard(pasteboard)
        let restoreNeeded = savedClipboard != nil

        if restoreNeeded {
            ServiceDispatcher.markClipboardRestorePending()
        }

        // Step 2 — Copy query to clipboard
        pasteboard.clearContents()
        pasteboard.setString(query, forType: .string)

        defer {
            // Step 6 — Restore clipboard after paste delay
            if restoreNeeded {
                Thread.sleep(forTimeInterval: serviceType.clipboardRestoreDelay)
                restoreClipboard(pasteboard, items: savedClipboard ?? [])
                ServiceDispatcher.clearClipboardRestorePending()
            }
        }

        // Step 3 — Activate app (warm or cold launch)
        let isColdLaunch = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty
        if let newChatURL {
            // Open via URL scheme — the app handles routing to a new conversation directly.
            // No keystroke needed; skip to paste after the app is frontmost.
            NSWorkspace.shared.open(newChatURL)
        } else {
            try activateApp(bundleID: bundleID, appURL: appURL, isColdLaunch: isColdLaunch)
        }

        // Step 4 — Wait for app to become frontmost
        let timeout: TimeInterval = isColdLaunch ? serviceType.coldLaunchTimeout : 3.0
        try waitForFrontmost(bundleID: bundleID, timeout: timeout, isColdLaunch: isColdLaunch)

        // Brief pause for the app's UI to settle after receiving focus before sending keystrokes.
        // - Cold launch: Electron apps are frontmost before their renderer is ready.
        // - Warm launch with URL scheme: app is already running but needs time to navigate
        //   to the new conversation before the input field is ready.
        let settleDelay: TimeInterval
        if isColdLaunch {
            settleDelay = serviceType.coldLaunchSettleDelay
        } else if newChatURL != nil {
            settleDelay = 1.0  // URL navigation needs time to complete even when app is warm
        } else {
            settleDelay = 0.25
        }
        Thread.sleep(forTimeInterval: settleDelay)

        // Step 5 — Send keystrokes
        let appName = serviceType.displayName

        // Skip keystroke when a newChatURL was used — the URL already opens a new conversation.
        if newChatURL == nil && keystroke != .none {
            let newChatScript = keystrokeScript(key: keystroke.key, modifiers: keystroke.modifiers, appName: appName)
            try runScript(newChatScript, appName: appName)
            // Give the destination app time to finish switching to a fresh thread
            // before we send the paste keystroke.
            let newConvoWait: TimeInterval = isColdLaunch
                ? serviceType.coldLaunchNewConversationReadyDelay
                : serviceType.newConversationReadyDelay
            Thread.sleep(forTimeInterval: newConvoWait)
        }

        let pasteScript = keystrokeScript(key: "v", modifiers: ["command"], appName: appName)
        try runScript(pasteScript, appName: appName)

        // Step 5b — Submit the pasted query (key code 36 = Return)
        let submitDelay = isColdLaunch ? serviceType.coldLaunchSubmitDelay : serviceType.submitDelay
        Thread.sleep(forTimeInterval: submitDelay)
        let returnScript = keyCodeScript(code: 36, modifiers: [])
        try runScript(returnScript, appName: appName)
    }

    // MARK: - App activation

    /// Uses NSWorkspace.openApplication for both warm and cold launches.
    /// NSRunningApplication.activate() is deprecated in macOS 14 and silently fails
    /// from a non-activating panel. openApplication handles both cases correctly.
    private static func activateApp(bundleID: String, appURL: URL, isColdLaunch: Bool) throws {
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        let semaphore = DispatchSemaphore(value: 0)
        NSWorkspace.shared.openApplication(at: appURL, configuration: config) { _, _ in
            semaphore.signal()
        }
        semaphore.wait()
    }

    // MARK: - Wait for frontmost

    private static func waitForFrontmost(bundleID: String, timeout: TimeInterval, isColdLaunch: Bool) throws {
        let deadline = Date().addingTimeInterval(timeout)
        let pollInterval: TimeInterval = 0.1

        while Date() < deadline {
            if NSWorkspace.shared.frontmostApplication?.bundleIdentifier == bundleID {
                return
            }
            Thread.sleep(forTimeInterval: pollInterval)
        }

        // One final check
        if NSWorkspace.shared.frontmostApplication?.bundleIdentifier == bundleID {
            return
        }

        if isColdLaunch {
            throw AppleScriptError.appLaunchTimeout
        }
        // For warm launch timeout, proceed anyway — the app is running, focus may have raced
    }

    // MARK: - Browser paste (best-effort, for LLMs without URL-based submission)

    /// Waits for a browser page to load, then pastes from clipboard and submits.
    /// Best-effort: if the user switches away in the delay window the paste goes elsewhere.
    static func pasteAndSubmitInFrontmostApp(after delay: TimeInterval) async {
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        var error: NSDictionary?
        let script = NSAppleScript(source: """
        tell application "System Events"
            keystroke "v" using command down
            delay 0.2
            key code 36
        end tell
        """)
        script?.executeAndReturnError(&error)
        if let error {
            let msg = error[NSAppleScript.errorMessage] as? String ?? "Unknown error"
            print("[Courier] Browser paste error: \(msg)")
            let isAccessibility = msg.contains("not allowed to send keystrokes")
            Task { @MainActor in
                if isAccessibility {
                    await NotificationHelper.showToast("Accessibility permission needed. Query is in clipboard — press Cmd+V.")
                } else {
                    await NotificationHelper.showToast("Paste failed. Query is in clipboard — press Cmd+V.")
                }
            }
        }
    }

    // MARK: - AppleScript execution

    /// Build a keystroke script using System Events. Never interpolates user text —
    /// the query is already on the clipboard and sent via Cmd+V.
    private static func keystrokeScript(key: String, modifiers: [String], appName: String) -> String {
        let modExpr = modifiers.isEmpty ? "" : " using {\(modifiers.map { "\($0) down" }.joined(separator: ", "))}"
        return """
        tell application "System Events"
            keystroke "\(key)"\(modExpr)
        end tell
        """
    }

    /// Build a key code script using System Events. Use for special keys like Return (36).
    private static func keyCodeScript(code: Int, modifiers: [String]) -> String {
        let modExpr = modifiers.isEmpty ? "" : " using {\(modifiers.map { "\($0) down" }.joined(separator: ", "))}"
        return """
        tell application "System Events"
            key code \(code)\(modExpr)
        end tell
        """
    }

    private static func runScript(_ source: String, appName: String) throws {
        var error: NSDictionary?
        let script = NSAppleScript(source: source)
        script?.executeAndReturnError(&error)

        if let error {
            let msg = error[NSAppleScript.errorMessage] as? String ?? "Unknown error"
            if let code = error[NSAppleScript.errorNumber] as? Int, code == -1743 {
                throw AppleScriptError.automationDenied(appName: appName)
            }
            // "not allowed to send keystrokes" = Accessibility permission denied
            if msg.contains("not allowed to send keystrokes") {
                throw AppleScriptError.accessibilityDenied
            }
            throw AppleScriptError.scriptError(msg)
        }
    }

    // MARK: - Clipboard save/restore

    /// Public access for browser-fallback path in LLMService.
    static func saveClipboardContents(_ pasteboard: NSPasteboard) -> [[(NSPasteboard.PasteboardType, Data)]]? {
        saveClipboard(pasteboard)
    }

    /// Public access for tests and browser-fallback restoration.
    static func restoreClipboardContents(
        _ pasteboard: NSPasteboard,
        items: [[(NSPasteboard.PasteboardType, Data)]]
    ) {
        restoreClipboard(pasteboard, items: items)
    }

    private static func saveClipboard(_ pasteboard: NSPasteboard) -> [[(NSPasteboard.PasteboardType, Data)]]? {
        // Skip if clipboard is empty
        guard pasteboard.changeCount > 0, let items = pasteboard.pasteboardItems, !items.isEmpty else {
            return nil
        }

        // Deep copy — proxy items are invalidated when pasteboard changes
        let saved: [[(NSPasteboard.PasteboardType, Data)]] = items.map { item in
            item.types.compactMap { type in
                guard let data = item.data(forType: type) else { return nil }
                // Skip if total would exceed 50MB
                return (type, data)
            }
        }

        // Check total size — skip save if > 50MB
        let totalBytes = saved.flatMap { $0 }.reduce(0) { $0 + $1.1.count }
        if totalBytes > 50_000_000 {
            Task { await NotificationHelper.showToast("Clipboard too large to save.") }
            return nil
        }

        return saved
    }

    private static func restoreClipboard(
        _ pasteboard: NSPasteboard,
        items: [[(NSPasteboard.PasteboardType, Data)]]
    ) {
        pasteboard.clearContents()
        let newItems = items.map { pairs -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in pairs {
                item.setData(data, forType: type)
            }
            return item
        }
        if !newItems.isEmpty {
            pasteboard.writeObjects(newItems)
        }
    }
}
