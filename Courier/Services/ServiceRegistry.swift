import Foundation

/// Concrete stub provider — dispatch implementation added in Phase 3.
struct StubServiceProvider: ServiceProvider {
    let type: ServiceType
    let browserURL: String
    let bundleIdentifier: String?
    let defaultSlashCommands: [String]
    let appendsQueryToURL: Bool

    func dispatch(query: String) async throws {
        // Phase 3: real dispatch via LLMService / SearchService
    }
}

/// Central registry of all service providers.
final class ServiceRegistry {

    private let providers: [ServiceType: ServiceProvider]

    init() {
        var map: [ServiceType: ServiceProvider] = [:]

        map[.claude] = StubServiceProvider(
            type: .claude,
            browserURL: "https://claude.ai/new",
            bundleIdentifier: "com.anthropic.claudefordesktop",
            defaultSlashCommands: ["/cl", "/claude"],
            appendsQueryToURL: false
        )
        map[.chatgpt] = StubServiceProvider(
            type: .chatgpt,
            browserURL: "https://chatgpt.com/",
            bundleIdentifier: "com.openai.chat",
            defaultSlashCommands: ["/ch", "/chatgpt"],
            appendsQueryToURL: false
        )
        map[.gemini] = StubServiceProvider(
            type: .gemini,
            browserURL: "https://gemini.google.com/app",
            bundleIdentifier: nil,
            defaultSlashCommands: ["/ge", "/gemini"],
            appendsQueryToURL: false
        )
        map[.perplexity] = StubServiceProvider(
            type: .perplexity,
            browserURL: "https://www.perplexity.ai/search?q=",
            bundleIdentifier: "ai.perplexity.mac",
            defaultSlashCommands: ["/p", "/perplexity"],
            appendsQueryToURL: true
        )
        map[.kagi] = StubServiceProvider(
            type: .kagi,
            browserURL: "https://kagi.com/search?q=",
            bundleIdentifier: nil,
            defaultSlashCommands: ["/k", "/kagi"],
            appendsQueryToURL: true
        )
        map[.google] = StubServiceProvider(
            type: .google,
            browserURL: "https://www.google.com/search?q=",
            bundleIdentifier: nil,
            defaultSlashCommands: ["/g", "/google"],
            appendsQueryToURL: true
        )
        map[.duckduckgo] = StubServiceProvider(
            type: .duckduckgo,
            browserURL: "https://duckduckgo.com/?q=",
            bundleIdentifier: nil,
            defaultSlashCommands: ["/d", "/ddg", "/duckduckgo"],
            appendsQueryToURL: true
        )

        providers = map
    }

    /// Returns the provider for the given service type.
    func provider(for type: ServiceType) -> ServiceProvider? {
        providers[type]
    }

    /// Returns the service type for an exact-match slash command (case-insensitive).
    /// "/c" does NOT match "/cl" — matching is exact, not prefix.
    func serviceType(forSlashCommand command: String) -> ServiceType? {
        let lower = command.lowercased()
        return SlashCommand.all.first(where: { $0.command == lower })?.serviceType
    }
}
