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

    // MARK: - Dispatch configuration

    /// Keystroke to open a new conversation before pasting.
    var newConversationKeystroke: LLMKeystroke {
        switch self {
        case .claude:      return .cmdN
        case .chatgpt:     return .cmdN
        case .perplexity:  return .none
        default:           return .none
        }
    }

    /// How long to wait (seconds) after pasting before restoring the clipboard.
    /// Longer for apps that process large pastes slowly (e.g. Electron).
    var clipboardRestoreDelay: TimeInterval {
        switch self {
        case .claude, .chatgpt, .perplexity: return 1.5
        default: return 1.0
        }
    }
}

// MARK: - LLMKeystroke

enum LLMKeystroke {
    case cmdN   // Claude, ChatGPT: Cmd+N opens new conversation
    case cmdL   // Alternative: some apps use Cmd+L to focus input
    case none   // Skip new-conversation step, just paste

    var key: String {
        switch self {
        case .cmdN: return "n"
        case .cmdL: return "l"
        case .none: return ""
        }
    }
}
