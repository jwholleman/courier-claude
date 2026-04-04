import SwiftUI

struct SetupWizardView: View {
    @Bindable var settings: AppSettings
    var onComplete: () -> Void

    @State private var currentStep = 0
    private let totalSteps = 4

    var body: some View {
        VStack(spacing: 0) {
            // Step content
            ZStack {
                switch currentStep {
                case 0: WelcomeStep()
                case 1: ServiceSelectionStep(settings: settings)
                case 2: HotkeySetupStep()
                case 3: SlashCommandStep(settings: settings)
                default: EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Setup step \(currentStep + 1) of \(totalSteps)")

            // Navigation
            HStack(spacing: 12) {
                if currentStep > 0 {
                    Button("Back") { currentStep -= 1 }
                        .keyboardShortcut("[", modifiers: .command)
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .accessibilityLabel("Back")
                        .accessibilityHint("Go to step \(currentStep) of \(totalSteps)")
                }

                if currentStep < totalSteps - 1 {
                    Button("Next") { currentStep += 1 }
                        .keyboardShortcut(.return, modifiers: [])
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .accessibilityLabel("Next")
                        .accessibilityHint("Go to step \(currentStep + 2) of \(totalSteps)")
                } else {
                    Button("Get Started") {
                        settings.hasCompletedSetup = true
                        onComplete()
                    }
                    .keyboardShortcut(.return, modifiers: [])
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .accessibilityLabel("Get Started")
                    .accessibilityHint("Complete setup and open Courier")
                }
            }
            .padding(.bottom, 32)
            .padding(.top, 8)
        }
    }
}

// MARK: - Welcome step

private struct WelcomeStep: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(nsImage: NSImage(named: "AppIcon") ?? NSApp.applicationIconImage)
                .resizable()
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .accessibilityHidden(true)

            Text("Courier is your quick launcher for searches and prompts")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }
}
