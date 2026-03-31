import SwiftUI
import KeyboardShortcuts

struct HotkeySetupStep: View {
    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("Set Your Hotkey")
                    .font(.title2.bold())
                Text("This is the shortcut that opens Courier from anywhere.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 16) {
                KeyboardShortcuts.Recorder("Launch Courier:", name: .toggleCourier)
                    .padding(.horizontal, 24)

                Button("Use Default (Option+Space)") {
                    KeyboardShortcuts.setShortcut(.init(.space, modifiers: .option), for: .toggleCourier)
                }
                .padding(.horizontal, 24)
            }

            Text("Tip: avoid shortcuts used by other apps like Spotlight (⌘Space).")
                .font(.callout)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding(40)
    }
}
