import SwiftUI

struct SetupWizardView: View {
    @Bindable var settings: AppSettings
    var onComplete: () -> Void

    @State private var currentStep = 0
    private let totalSteps = 5

    var body: some View {
        VStack(spacing: 0) {
            // Step content
            ZStack {
                switch currentStep {
                case 0: WelcomeStep()
                case 1: HotkeySetupStep()
                case 2: LLMSelectionStep(settings: settings)
                case 3: SearchProviderStep(settings: settings)
                case 4: SlashCommandStep(settings: settings)
                default: EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            // Navigation bar
            HStack {
                // Step indicators
                HStack(spacing: 6) {
                    ForEach(0..<totalSteps, id: \.self) { step in
                        Circle()
                            .fill(step == currentStep
                                  ? Color(nsColor: .controlAccentColor)
                                  : Color(nsColor: .tertiaryLabelColor))
                            .frame(width: 6, height: 6)
                    }
                }

                Spacer()

                HStack(spacing: 12) {
                    if currentStep > 0 {
                        Button("Back") { currentStep -= 1 }
                            .keyboardShortcut("[", modifiers: .command)
                    }

                    if currentStep < totalSteps - 1 {
                        Button("Next") { currentStep += 1 }
                            .keyboardShortcut(.return, modifiers: [])
                            .buttonStyle(.borderedProminent)
                    } else {
                        Button("Finish") {
                            settings.hasCompletedSetup = true
                            onComplete()
                        }
                        .keyboardShortcut(.return, modifiers: [])
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
    }
}

// MARK: - Welcome step

private struct WelcomeStep: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "paperplane.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color(nsColor: .controlAccentColor))

            VStack(spacing: 8) {
                Text("Welcome to Courier")
                    .font(.title.bold())
                Text("Your universal query launcher.\nPress your hotkey, type a query, pick a destination.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Text("This short setup takes about a minute.")
                .font(.callout)
                .foregroundStyle(.tertiary)
        }
        .padding(40)
    }
}
