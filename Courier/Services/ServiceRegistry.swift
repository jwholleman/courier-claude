import Foundation

/// Central registry of all service providers.
@MainActor
final class ServiceRegistry {

    private let providers: [ServiceType: ServiceProvider]
    var settings: AppSettings? {
        didSet {
            // Propagate settings to all LLMService providers for keystroke overrides
            for provider in providers.values {
                (provider as? LLMService)?.settings = settings
            }
        }
    }

    init() {
        var map: [ServiceType: ServiceProvider] = [:]

        map[.claude] = LLMService(
            type: .claude,
            browserURL: "https://claude.ai/new",
            bundleIdentifier: "com.anthropic.claudefordesktop",
            slashCommands: ["/cl", "/claude"],
            appendsQueryToURL: false
        )
        map[.claudeCode] = ClaudeCodeService(
            type: .claudeCode,
            slashCommands: ["/cc", "/claudecode"]
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
        map[.youtube] = SearchService(
            type: .youtube,
            browserURL: "https://www.youtube.com/results?search_query=",
            slashCommands: ["/yt", "/youtube"]
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
    /// Checks user-defined custom commands first, then built-in defaults.
    /// "/c" does NOT match "/cl" — matching is exact, not prefix.
    func serviceType(forSlashCommand command: String) -> ServiceType? {
        let lower = command.lowercased(with: Locale(identifier: "en"))

        // Check custom commands first
        if let custom = settings?.customSlashCommands {
            for (rawValue, cmds) in custom {
                if cmds.contains(where: { $0.lowercased(with: Locale(identifier: "en")) == lower }),
                   let service = ServiceType(rawValue: rawValue) {
                    return service
                }
            }
        }

        // Fall back to defaults
        return SlashCommand.all.first(where: { $0.command == lower })?.serviceType
    }
}
