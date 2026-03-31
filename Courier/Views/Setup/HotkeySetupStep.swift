import SwiftUI
import KeyboardShortcuts

struct HotkeySetupStep: View {
    @State private var hasShortcut = KeyboardShortcuts.getShortcut(for: .toggleCourier) != nil

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("Set Your Hotkey")
                    .font(.title2.bold())
                Text("This shortcut opens Courier from anywhere on your Mac.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 16) {
                // Recorder — click it, then press your desired key combination
                KeyboardShortcuts.Recorder("Launch Courier:", name: .toggleCourier)
                    .onChange(of: KeyboardShortcuts.getShortcut(for: .toggleCourier) != nil) { _, new in
                        hasShortcut = new
                    }

                if !hasShortcut {
                    Label("No shortcut set — click the field above and press a key combination.",
                          systemImage: "exclamationmark.triangle")
                        .font(.callout)
                        .foregroundStyle(.orange)
                }

                Button("Reset to Default (⌥Space)") {
                    KeyboardShortcuts.setShortcut(.init(.space, modifiers: .option), for: .toggleCourier)
                    hasShortcut = true
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 40)

            VStack(spacing: 4) {
                Text("How to record:")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Text("1. Click the shortcut field   2. Press your desired key combination   3. Done")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)
        }
        .padding(40)
        .onAppear {
            hasShortcut = KeyboardShortcuts.getShortcut(for: .toggleCourier) != nil
        }
    }
}
