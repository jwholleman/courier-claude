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
        browserFallback: @escaping () async throws -> Void
    ) async throws {
        guard AXIsProcessTrusted() else {
            await NotificationHelper.postAccessibilityRevoked()
            try await browserFallback()
            return
        }

        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                dispatchQueue.async {
                    do {
                        try dispatchSync(
                            query: query,
                            bundleID: bundleID,
                            appURL: appURL,
                            serviceType: serviceType
                        )
                        continuation.resume()
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        } catch AppleScriptError.automationDenied(let appName) {
            await NotificationHelper.postAutomationDenied(appName: appName)
            try await browserFallback()
        } catch AppleScriptError.appLaunchTimeout {
            let appName = serviceType.displayName
            await NotificationHelper.showToast("'\(appName)' took too long to launch. Query copied to clipboard.")
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(query, forType: .string)
            try await browserFallback()
        } catch {
            let appName = serviceType.displayName
            await NotificationHelper.showToast("Couldn't paste into \(appName). Query copied to clipboard. Opening in browser.")
            try await browserFallback()
        }
    }

    // MARK: - Synchronous dispatch (runs on dispatchQueue)

    private static func dispatchSync(
        query: String,
        bundleID: String,
        appURL: URL,
        serviceType: ServiceType
    ) throws {
        let pasteboard = NSPasteboard.general

        // Step 1 — Deep-copy clipboard (proxy items become invalid after modification)
        let savedClipboard = saveClipboard(pasteboard)
        let restoreNeeded = savedClipboard != nil

        // Step 2 — Copy query to clipboard
        pasteboard.clearContents()
        pasteboard.setString(query, forType: .string)

        defer {
            // Step 6 — Restore clipboard after paste delay
            if restoreNeeded {
                Thread.sleep(forTimeInterval: serviceType.clipboardRestoreDelay)
                restoreClipboard(pasteboard, items: savedClipboard ?? [])
            }
        }

        // Step 3 — Activate app (warm or cold launch)
        let isColdLaunch = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty
        try activateApp(bundleID: bundleID, appURL: appURL, isColdLaunch: isColdLaunch)

        // Step 4 — Wait for app to become frontmost
        let timeout: TimeInterval = isColdLaunch ? 10.0 : 3.0
        try waitForFrontmost(bundleID: bundleID, timeout: timeout, isColdLaunch: isColdLaunch)

        // Step 5 — Send keystrokes
        let appName = serviceType.displayName
        let keystroke = serviceType.newConversationKeystroke

        if keystroke != .none {
            let cmdNScript = keystrokeScript(key: keystroke.key, modifiers: ["command"], appName: appName)
            try runScript(cmdNScript, appName: appName)
            Thread.sleep(forTimeInterval: 0.3) // Wait for new conversation UI
        }

        let pasteScript = keystrokeScript(key: "v", modifiers: ["command"], appName: appName)
        try runScript(pasteScript, appName: appName)
    }

    // MARK: - App activation

    private static func activateApp(bundleID: String, appURL: URL, isColdLaunch: Bool) throws {
        if !isColdLaunch {
            if let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first {
                app.activate()
            }
        } else {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            let semaphore = DispatchSemaphore(value: 0)
            NSWorkspace.shared.openApplication(at: appURL, configuration: config) { _, _ in
                semaphore.signal()
            }
            semaphore.wait()
        }
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

    private static func runScript(_ source: String, appName: String) throws {
        var error: NSDictionary?
        let script = NSAppleScript(source: source)
        script?.executeAndReturnError(&error)

        if let error {
            let msg = error[NSAppleScript.errorMessage] as? String ?? "Unknown error"
            // Automation denial produces error -1743
            if let code = error[NSAppleScript.errorNumber] as? Int, code == -1743 {
                throw AppleScriptError.automationDenied(appName: appName)
            }
            throw AppleScriptError.scriptError(msg)
        }
    }

    // MARK: - Clipboard save/restore

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
