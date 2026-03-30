import Foundation

enum ServiceCategory: String, Codable {
    case llm
    case search
}

enum ServiceType: String, Codable, CaseIterable, Identifiable {
    case claude, chatgpt, gemini, perplexity, kagi, google, duckduckgo

    var id: String { rawValue }

    var category: ServiceCategory {
        switch self {
        case .claude, .chatgpt, .gemini, .perplexity: return .llm
        case .kagi, .google, .duckduckgo: return .search
        }
    }

    var displayName: String {
        switch self {
        case .claude: return "Claude"
        case .chatgpt: return "ChatGPT"
        case .gemini: return "Gemini"
        case .perplexity: return "Perplexity"
        case .kagi: return "Kagi"
        case .google: return "Google"
        case .duckduckgo: return "DuckDuckGo"
        }
    }

    var iconName: String { rawValue }  // Matches asset catalog name

    /// Display order: LLMs first, then search engines
    static let displayOrder: [ServiceType] = [
        .claude, .chatgpt, .gemini, .perplexity,
        .kagi, .google, .duckduckgo
    ]
}
