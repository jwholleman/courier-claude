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
        case .claude:     return .shiftCmdO   // Verified: Shift+Cmd+O opens new conversation
        case .chatgpt:    return .none         // ChatGPT opens to new conversation automatically
        case .perplexity: return .none
        default:          return .none
        }
    }

    /// How long to wait (seconds) after pasting before sending Return to submit.
    var submitDelay: TimeInterval {
        switch self {
        case .chatgpt: return 0.5  // Electron app needs more time to register paste
        default:       return 0.1
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

enum LLMKeystroke: Equatable {
    case cmdN        // Cmd+N
    case cmdL        // Cmd+L
    case shiftCmdO   // Shift+Cmd+O (Claude)
    case none

    var key: String {
        switch self {
        case .cmdN:      return "n"
        case .cmdL:      return "l"
        case .shiftCmdO: return "o"
        case .none:      return ""
        }
    }

    var modifiers: [String] {
        switch self {
        case .cmdN:      return ["command"]
        case .cmdL:      return ["command"]
        case .shiftCmdO: return ["shift", "command"]
        case .none:      return []
        }
    }
}
