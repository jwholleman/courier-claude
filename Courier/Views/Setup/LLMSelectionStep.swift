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
                Text("Select which AI services you'd like to use.\nAt least one must be enabled.")
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
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { isEnabled },
                set: { onChange($0) }
            ))
            .disabled(!canDisable && isEnabled)
            .labelsHidden()
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
        case .claude:      return "com.anthropic.claudefordesktop"
        case .chatgpt:     return "com.openai.chat"
        case .perplexity:  return "ai.perplexity.mac"
        default:           return nil
        }
    }
}
