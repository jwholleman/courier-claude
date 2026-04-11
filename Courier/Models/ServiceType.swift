import AppKit
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
        case .claude, .chatgpt:
            return true
        case .claudeCode, .gemini, .perplexity, .kagi, .google, .youtube, .duckduckgo:
            return false
        }
    }

    var desktopAppBundleIdentifier: String? {
        switch self {
        case .claude:
            return "com.anthropic.claudefordesktop"
        case .chatgpt:
            return "com.openai.chat"
        case .perplexity:
            return "ai.perplexity.mac"
        case .claudeCode, .gemini, .kagi, .google, .youtube, .duckduckgo:
            return nil
        }
    }

    var isDesktopAppDetected: Bool {
        guard let bundleID = desktopAppBundleIdentifier else { return false }
        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) != nil
    }

    static var desktopAppServices: [ServiceType] {
        displayOrder.filter { $0.desktopAppBundleIdentifier != nil }
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
        case .claude:  return .shiftCmdO
        case .chatgpt, .perplexity: return .cmdN
        default:       return .none
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
        case .claude:  return 0.1
        case .chatgpt: return 0.5  // Electron app needs more time to register paste
        default:       return 0.1
        }
    }

    /// Extra submit delay for cold launches where the destination app may accept the paste
    /// before its composer is fully ready to handle the final Return keystroke.
    var coldLaunchSubmitDelay: TimeInterval {
        switch self {
        case .claude:  return 0.75
        case .chatgpt: return 0.75
        default:       return submitDelay
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

    /// How long to wait (seconds) for the app to become frontmost on a cold launch.
    /// Claude.app and ChatGPT.app are Electron apps and can take 10–15 s on first run.
    var coldLaunchTimeout: TimeInterval {
        switch self {
        case .claude:   return 15.0
        case .chatgpt:  return 12.0
        default:        return 10.0
        }
    }

    /// Extra UI settle time (seconds) after the app becomes frontmost on a cold launch,
    /// before sending any keystrokes. Electron apps are frontmost before their renderer
    /// is fully ready to accept input.
    var coldLaunchSettleDelay: TimeInterval {
        switch self {
        case .claude, .chatgpt: return 2.0
        default:                return 0.5
        }
    }

    /// How long to wait after the "new conversation" shortcut before pasting.
    /// ChatGPT needs more time for the fresh thread input to mount than Claude does.
    var newConversationReadyDelay: TimeInterval {
        switch self {
        case .chatgpt, .perplexity: return 0.85
        case .claude:  return 0.3
        default:       return 0.3
        }
    }

    /// Same as `newConversationReadyDelay`, but for cold app launches where the new-thread
    /// UI animation and renderer startup are both still settling.
    var coldLaunchNewConversationReadyDelay: TimeInterval {
        switch self {
        case .chatgpt, .perplexity: return 1.4
        case .claude:  return 1.0
        default:       return 1.0
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
