import SwiftUI

struct LLMSelectionStep: View {
    @Bindable var settings: AppSettings

    private let llmServices: [ServiceType] = [.claude, .chatgpt, .gemini, .perplexity]

    private var enabledLLMs: [ServiceType] {
        llmServices.filter { !settings.disabledServices.contains($0) }
    }

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("Choose Your AI Assistants")
                    .font(.title2.bold())
                Text("Select the AI services you'd like to use.\nYou can change these anytime in Settings.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 10) {
                ForEach(llmServices) { service in
                    ServiceToggleRow(
                        service: service,
                        isEnabled: !settings.disabledServices.contains(service),
                        canDisable: enabledLLMs.count > 1 || settings.disabledServices.contains(service)
                    ) { enabled in
                        if enabled {
                            settings.disabledServices.remove(service)
                        } else {
                            settings.disabledServices.insert(service)
                        }
                    }
                }
            }
            .padding(.horizontal, 32)
        }
        .padding(40)
    }
}

// MARK: - Shared row

struct ServiceToggleRow: View {
    let service: ServiceType
    let isEnabled: Bool
    let canDisable: Bool
    let onChange: (Bool) -> Void

    var body: some View {
        HStack {
            Image(service.iconName, bundle: nil)
                .resizable()
                .renderingMode(.template)
                .frame(width: 18, height: 18)
                .foregroundStyle(isEnabled ? Color(nsColor: .controlAccentColor) : .secondary)
                .accessibilityHidden(true)

            Text(service.displayName)
                .font(.body)

            if isInstalledNatively {
                Text("App installed")
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(nsColor: .controlAccentColor).opacity(0.15))
                    .foregroundStyle(Color(nsColor: .controlAccentColor))
                    .clipShape(Capsule())
                    .accessibilityLabel("\(service.displayName) native app is installed")
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { isEnabled },
                set: { onChange($0) }
            ))
            .disabled(!canDisable && isEnabled)
            .labelsHidden()
            .accessibilityLabel(isEnabled ? "\(service.displayName), enabled" : "\(service.displayName), disabled")
            .accessibilityHint(canDisable ? "Toggle to enable or disable \(service.displayName)" : "Cannot disable — at least one AI assistant must remain enabled")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var isInstalledNatively: Bool {
        guard let bundleID = nativeBundleID else { return false }
        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) != nil
    }

    private var nativeBundleID: String? {
        switch service {
        case .claude:   return "com.anthropic.claudefordesktop"
        case .chatgpt:  return "com.openai.chat"
        default:        return nil
        }
    }
}
