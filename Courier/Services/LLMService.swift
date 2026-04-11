import AppKit
import Foundation

final class LLMService: ServiceProvider {
    let type: ServiceType
    let browserURL: String
    let bundleIdentifier: String?
    let defaultSlashCommands: [String]
    let appendsQueryToURL: Bool
    /// URL scheme to open a new conversation directly (e.g. "chatgpt://new").
    /// When set, the dispatcher opens this URL instead of activating the app + sending a keystroke.
    let nativeNewChatURLScheme: String?

    weak var settings: AppSettings?

    init(
        type: ServiceType,
        browserURL: String,
        bundleIdentifier: String?,
        slashCommands: [String],
        appendsQueryToURL: Bool = false,
        nativeNewChatURLScheme: String? = nil
    ) {
        self.type = type
        self.browserURL = browserURL
        self.bundleIdentifier = bundleIdentifier
        self.defaultSlashCommands = slashCommands
        self.appendsQueryToURL = appendsQueryToURL
        self.nativeNewChatURLScheme = nativeNewChatURLScheme
    }

    func dispatch(query: String) async throws {
        let truncated = String(query.prefix(8000))
        let shouldUseDesktopApps = await MainActor.run { settings?.useDesktopApps ?? true }

        if shouldUseDesktopApps,
           let bundleID = bundleIdentifier,
           let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            try await dispatchNative(
                query: truncated,
                bundleID: bundleID,
                appURL: appURL,
                allowsBrowserFallback: false
            )
        } else {
            try await dispatchBrowser(query: truncated)
        }
    }

    // MARK: - Browser fallback

    private func dispatchBrowser(query: String) async throws {
        if appendsQueryToURL {
            // URL-based submission (Perplexity) — query is in the URL, no clipboard needed
            guard let url = SearchService.buildURL(base: browserURL, query: query) else {
                await copyToClipboardAndNotify(query: query, reason: "Couldn't build URL.")
                return
            }
            let opened = NSWorkspace.shared.open(url)
            if !opened {
                await copyToClipboardAndNotify(query: query, reason: "Couldn't open browser.")
            }
        } else {
            // LLM-style: open base URL, save clipboard, write query, paste after page load, restore
            guard let url = URL(string: browserURL) else { return }

            let pasteboard = NSPasteboard.general
            let savedClipboard = AppleScriptHelper.saveClipboardContents(pasteboard)

            // Resolve the default browser app URL before opening — reliable regardless of
            // focus changes. previousApp.activate() fires at ~150ms and would corrupt
            // any frontmost-app polling approach.
            let browserAppURL = NSWorkspace.shared.urlForApplication(toOpen: url)

            // Detect cold browser launch before opening so we can extend the page-load wait.
            let isBrowserColdLaunch: Bool = {
                guard let appURL = browserAppURL,
                      let bundleID = Bundle(url: appURL)?.bundleIdentifier else { return false }
                return NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty
            }()

            let opened = NSWorkspace.shared.open(url)
            pasteboard.clearContents()
            pasteboard.setString(query, forType: .string)

            if opened, let browserAppURL {
                if savedClipboard != nil {
                    ServiceDispatcher.markClipboardRestorePending()
                }
                let savedClipboardCopy = savedClipboard
                Task.detached { [self] in
                    // Cold browser launch needs time to start up and load the page.
                    // Warm launch (tab opened in running browser) is much faster.
                    let pageLoadWait: UInt64 = isBrowserColdLaunch ? 3_000_000_000 : 900_000_000
                    try? await Task.sleep(nanoseconds: pageLoadWait)

                    // Re-activate the browser by app URL — no polling, no race condition
                    await self.activateBrowser(at: browserAppURL)

                    // Wait for the browser to become truly frontmost and its input to focus.
                    // 300ms was too short on macOS 26; 800ms gives the window time to settle.
                    try? await Task.sleep(nanoseconds: 800_000_000)
                    await AppleScriptHelper.pasteAndSubmitInFrontmostApp(after: 0)

                    // Restore clipboard after paste
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    if let saved = savedClipboardCopy {
                        AppleScriptHelper.restoreClipboardContents(pasteboard, items: saved)
                        ServiceDispatcher.clearClipboardRestorePending()
                    }
                }
            } else {
                await NotificationHelper.showToast("Couldn't open browser. Query copied to clipboard.")
            }
        }
    }

    // MARK: - Native app dispatch (AppleScript)

    private func dispatchNative(
        query: String,
        bundleID: String,
        appURL: URL,
        allowsBrowserFallback: Bool
    ) async throws {
        // Resolve keystroke on MainActor before entering background dispatch
        let keystroke = await MainActor.run { type.effectiveKeystroke(settings: settings) }
        let newChatURL = nativeNewChatURLScheme.flatMap { URL(string: $0) }
        try await AppleScriptHelper.dispatch(
            query: query,
            bundleID: bundleID,
            appURL: appURL,
            serviceType: type,
            keystroke: keystroke,
            newChatURL: newChatURL,
            allowsBrowserFallback: allowsBrowserFallback,
            browserFallback: { [weak self] in
                guard let self else { return }
                try await self.dispatchBrowser(query: query)
            }
        )
    }

    // MARK: - Helpers

    private func copyToClipboardAndNotify(query: String, reason: String) async {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(query, forType: .string)
        await NotificationHelper.showToast("\(reason) Query copied to clipboard.")
    }

    private func activateBrowser(at url: URL) async {
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        await withCheckedContinuation { continuation in
            NSWorkspace.shared.openApplication(at: url, configuration: config) { _, _ in
                continuation.resume()
            }
        }
    }
}
