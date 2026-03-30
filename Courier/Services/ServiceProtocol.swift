import Foundation

protocol ServiceProvider {
    var type: ServiceType { get }
    var browserURL: String { get }               // Base URL for browser dispatch
    var bundleIdentifier: String? { get }         // Native app bundle ID, nil if browser-only
    var defaultSlashCommands: [String] { get }    // e.g., ["/cl", "/claude"]
    var appendsQueryToURL: Bool { get }           // true for search engines and Perplexity

    /// Dispatch the query to this service. Throws on failure.
    func dispatch(query: String) async throws
}
