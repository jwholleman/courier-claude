import AppKit
import Foundation

final class LLMService: ServiceProvider {
    let type: ServiceType
    let browserURL: String
    let bundleIdentifier: String?
    let defaultSlashCommands: [String]
    let appendsQueryToURL: Bool

    /// How long (seconds) to wait after sending Cmd+N before pasting.
    var newConversationDelay: TimeInterval = 0.3

    init(
        type: ServiceType,
        browserURL: String,
        bundleIdentifier: String?,
        slashCommands: [String],
        appendsQueryToURL: Bool = false
    ) {
        self.type = type
        self.browserURL = browserURL
        self.bundleIdentifier = bundleIdentifier
        self.defaultSlashCommands = slashCommands
        self.appendsQueryToURL = appendsQueryToURL
    }

    func dispatch(query: String) async throws {
        let truncated = String(query.prefix(8000))

        // Check if native app is installed (cached at launch, refreshed on app notifications)
        if let bundleID = bundleIdentifier,
           let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            try await dispatchNative(query: truncated, bundleID: bundleID, appURL: appURL)
        } else {
            try await dispatchBrowser(query: truncated)
        }
    }

    // MARK: - Browser fallback

    private func dispatchBrowser(query: String) async throws {
        if appendsQueryToURL {
            // Search-style URL (Perplexity browser)
            guard let url = SearchService.buildURL(base: browserURL, query: query) else {
                await copyToClipboardAndNotify(query: query, reason: "Couldn't build URL.")
                return
            }
            let opened = NSWorkspace.shared.open(url)
            if !opened {
                await copyToClipboardAndNotify(query: query, reason: "Couldn't open browser.")
            }
        } else {
            // LLM-style: open base URL, copy query to clipboard
            guard let url = URL(string: browserURL) else { return }
            let opened = NSWorkspace.shared.open(url)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(query, forType: .string)
            if opened {
                await NotificationHelper.showToast("Query copied to clipboard — paste into the conversation.")
            } else {
                await NotificationHelper.showToast("Couldn't open browser. Query copied to clipboard.")
            }
        }
    }

    // MARK: - Native app dispatch (AppleScript)

    private func dispatchNative(query: String, bundleID: String, appURL: URL) async throws {
        try await AppleScriptHelper.dispatch(
            query: query,
            bundleID: bundleID,
            appURL: appURL,
            serviceType: type,
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
}
