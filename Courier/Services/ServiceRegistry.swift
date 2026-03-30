import Foundation

/// Central registry of all service providers.
final class ServiceRegistry {

    private let providers: [ServiceType: ServiceProvider]

    init() {
        var map: [ServiceType: ServiceProvider] = [:]

        map[.claude] = LLMService(
            type: .claude,
            browserURL: "https://claude.ai/new",
            bundleIdentifier: "com.anthropic.claudefordesktop",
            slashCommands: ["/cl", "/claude"],
            appendsQueryToURL: false
        )
        map[.chatgpt] = LLMService(
            type: .chatgpt,
            browserURL: "https://chatgpt.com/",
            bundleIdentifier: "com.openai.chat",
            slashCommands: ["/ch", "/chatgpt"],
            appendsQueryToURL: false
        )
        map[.gemini] = LLMService(
            type: .gemini,
            browserURL: "https://gemini.google.com/app",
            bundleIdentifier: nil,
            slashCommands: ["/ge", "/gemini"],
            appendsQueryToURL: false
        )
        map[.perplexity] = LLMService(
            type: .perplexity,
            browserURL: "https://www.perplexity.ai/search?q=",
            bundleIdentifier: nil,  // URL-based browser submission works reliably; native app has AX issues
            slashCommands: ["/p", "/perplexity"],
            appendsQueryToURL: true
        )
        map[.kagi] = SearchService(
            type: .kagi,
            browserURL: "https://kagi.com/search?q=",
            slashCommands: ["/k", "/kagi"]
        )
        map[.google] = SearchService(
            type: .google,
            browserURL: "https://www.google.com/search?q=",
            slashCommands: ["/g", "/google"]
        )
        map[.duckduckgo] = SearchService(
            type: .duckduckgo,
            browserURL: "https://duckduckgo.com/?q=",
            slashCommands: ["/d", "/ddg", "/duckduckgo"]
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
