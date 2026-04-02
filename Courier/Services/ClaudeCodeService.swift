import AppKit
import Foundation

final class ClaudeCodeService: ServiceProvider {
    let type: ServiceType
    let browserURL: String = ""
    let bundleIdentifier: String? = nil
    let defaultSlashCommands: [String]
    let appendsQueryToURL: Bool = false

    init(type: ServiceType, slashCommands: [String]) {
        self.type = type
        self.defaultSlashCommands = slashCommands
    }

    func dispatch(query: String) async throws {
        let prompt = String(query.prefix(8000))

        guard let executablePath = resolveClaudeExecutablePath() else {
            let message: String
            if !prompt.isEmpty {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(prompt, forType: .string)
                message = "Claude Code isn't available. Query copied to clipboard."
            } else {
                message = "Claude Code isn't available on this Mac."
            }
            await NotificationHelper.showToast(message)
            return
        }

        let terminalCommand = buildTerminalCommand(executablePath: executablePath, prompt: prompt)
        try await MainActor.run {
            try openTerminal(with: terminalCommand)
        }
    }

    private func resolveClaudeExecutablePath() -> String? {
        let fileManager = FileManager.default
        let candidatePaths = [
            fileManager.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support/Claude/claude-code")
                .path,
            "/opt/homebrew/bin/claude",
            "/usr/local/bin/claude"
        ]

        if let installedDirectory = candidatePaths.first,
           let versions = try? fileManager.contentsOfDirectory(atPath: installedDirectory)
            .sorted(by: { $0.compare($1, options: .numeric) == .orderedDescending }),
           let latestVersion = versions.first {
            let bundledBinary = URL(fileURLWithPath: installedDirectory)
                .appendingPathComponent(latestVersion)
                .appendingPathComponent("claude.app/Contents/MacOS/claude")
                .path
            if fileManager.isExecutableFile(atPath: bundledBinary) {
                return bundledBinary
            }
        }

        return candidatePaths
            .dropFirst()
            .first(where: { fileManager.isExecutableFile(atPath: $0) })
    }

    private func buildTerminalCommand(executablePath: String, prompt: String) -> String {
        let homePath = FileManager.default.homeDirectoryForCurrentUser.path
        let promptArgument = prompt.isEmpty ? "" : " " + shellQuote(prompt)
        return "cd \(shellQuote(homePath)); \(shellQuote(executablePath))\(promptArgument)"
    }

    private func openTerminal(with command: String) throws {
        let source = """
        tell application "Terminal"
            activate
            do script "\(appleScriptQuote(command))"
        end tell
        """

        guard let script = NSAppleScript(source: source) else {
            throw NSError(
                domain: "ClaudeCodeService",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Couldn't create the Terminal launch script."]
            )
        }

        var errorInfo: NSDictionary?
        script.executeAndReturnError(&errorInfo)

        if let errorInfo {
            throw NSError(
                domain: "ClaudeCodeService",
                code: 1,
                userInfo: errorInfo as? [String: Any]
            )
        }
    }

    private func shellQuote(_ string: String) -> String {
        "'" + string.replacingOccurrences(of: "'", with: "'\"'\"'") + "'"
    }

    private func appleScriptQuote(_ string: String) -> String {
        string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
