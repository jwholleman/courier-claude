import Foundation

enum ServiceType: String, Codable, CaseIterable, Identifiable {
    case claude, claudeCode = "claude-code", chatgpt, gemini, perplexity, kagi, google, youtube, duckduckgo

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .claude: return "Claude"
        case .claudeCode: return "Claude Code"
        case .chatgpt: return "ChatGPT"
        case .gemini: return "Gemini"
        case .perplexity: return "Perplexity"
        case .kagi: return "Kagi"
        case .google: return "Google"
        case .youtube: return "YouTube"
        case .duckduckgo: return "DuckDuckGo"
        }
    }

    var iconName: String { rawValue }  // Matches asset catalog name

    var settingsIconName: String {
        switch self {
        case .duckduckgo: return "duckduckgoNegative"
        case .claudeCode: return "claudeCodeNegative"
        case .youtube: return "youtubeNegative"
        default: return iconName
        }
    }

    var supportsNativeKeystrokeConfiguration: Bool {
        switch self {
        case .claude, .chatgpt, .gemini, .perplexity:
            return true
        case .claudeCode, .kagi, .google, .youtube, .duckduckgo:
            return false
        }
    }

    /// Default display order for enabled services in Settings and the launcher.
    static let displayOrder: [ServiceType] = [
        .claude, .claudeCode, .chatgpt, .gemini, .perplexity,
        .kagi, .google, .youtube, .duckduckgo
    ]

    // MARK: - Dispatch configuration

    /// Keystroke to open a new conversation before pasting.
    /// Default keystroke — can be overridden per-user in Settings.
    var defaultNewConversationKeystroke: LLMKeystroke {
        switch self {
        case .claude:     return .shiftCmdO
        case .chatgpt:    return .none
        case .perplexity: return .none
        default:          return .none
        }
    }

    var newConversationKeystroke: LLMKeystroke {
        defaultNewConversationKeystroke
    }

    /// Returns the effective keystroke, respecting user overrides in settings.
    /// Must be called from @MainActor context (settings is @MainActor).
    @MainActor
    func effectiveKeystroke(settings: AppSettings?) -> LLMKeystroke {
        guard let raw = settings?.keystrokeOverrides[rawValue],
              let override = LLMKeystroke(rawValue: raw) else {
            return defaultNewConversationKeystroke
        }
        return override
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

enum LLMKeystroke: String, Equatable, CaseIterable {
    case cmdN        = "cmdN"
    case cmdL        = "cmdL"
    case shiftCmdO   = "shiftCmdO"
    case none        = "none"

    var displayName: String {
        switch self {
        case .cmdN:      return "Cmd+N (New conversation)"
        case .cmdL:      return "Cmd+L (Focus input)"
        case .shiftCmdO: return "Shift+Cmd+O (New conversation)"
        case .none:      return "None (Just paste)"
        }
    }

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
