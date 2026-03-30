import AppKit
import Foundation

final class SearchService: ServiceProvider {
    let type: ServiceType
    let browserURL: String
    let bundleIdentifier: String? = nil
    let defaultSlashCommands: [String]
    let appendsQueryToURL: Bool = true

    init(type: ServiceType, browserURL: String, slashCommands: [String]) {
        self.type = type
        self.browserURL = browserURL
        self.defaultSlashCommands = slashCommands
    }

    func dispatch(query: String) async throws {
        let truncated = String(query.prefix(8000))
        guard let url = SearchService.buildURL(base: browserURL, query: truncated) else {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(truncated, forType: .string)
            await NotificationHelper.showToast("Couldn't build URL. Query copied to clipboard.")
            return
        }
        let opened = NSWorkspace.shared.open(url)
        if !opened {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(truncated, forType: .string)
            await NotificationHelper.showToast("Couldn't open browser. Query copied to clipboard.")
        }
    }

    // MARK: - URL construction (internal for testing)

    static func encodeQuery(_ query: String) -> String {
        // Custom character set — urlQueryAllowed does NOT encode &, =, +, #
        // which would corrupt query parameters (e.g. "a&b=c" would add a spurious param)
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&=+#")
        return query.addingPercentEncoding(withAllowedCharacters: allowed) ?? query
    }

    static func buildURL(base: String, query: String) -> URL? {
        let encoded = encodeQuery(query)
        return URL(string: base + encoded)
    }
}
