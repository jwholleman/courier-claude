import Foundation

/// Maps slash command strings to service types.
/// Matching is exact and case-insensitive (e.g., "/cl" matches Claude, "/c" does NOT).
struct SlashCommand {
    let command: String        // e.g., "/cl"
    let serviceType: ServiceType

    /// All registered slash commands across all services.
    static let all: [SlashCommand] = [
        SlashCommand(command: "/cl",        serviceType: .claude),
        SlashCommand(command: "/claude",    serviceType: .claude),
        SlashCommand(command: "/ch",        serviceType: .chatgpt),
        SlashCommand(command: "/chatgpt",   serviceType: .chatgpt),
        SlashCommand(command: "/ge",        serviceType: .gemini),
        SlashCommand(command: "/gemini",    serviceType: .gemini),
        SlashCommand(command: "/p",         serviceType: .perplexity),
        SlashCommand(command: "/perplexity",serviceType: .perplexity),
        SlashCommand(command: "/k",         serviceType: .kagi),
        SlashCommand(command: "/kagi",      serviceType: .kagi),
        SlashCommand(command: "/g",         serviceType: .google),
        SlashCommand(command: "/google",    serviceType: .google),
        SlashCommand(command: "/d",         serviceType: .duckduckgo),
        SlashCommand(command: "/ddg",       serviceType: .duckduckgo),
        SlashCommand(command: "/duckduckgo",serviceType: .duckduckgo),
    ]
}
