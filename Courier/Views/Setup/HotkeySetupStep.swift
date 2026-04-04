import SwiftUI
import KeyboardShortcuts

struct HotkeySetupStep: View {
    @State private var hasShortcut = KeyboardShortcuts.getShortcut(for: .toggleCourier) != nil

    var body: some View {
        VStack(spacing: 24) {
            Text("Set Your Hotkey")
                .font(.title.bold())

            VStack(spacing: 16) {
                // Recorder — click it, then press your desired key combination
                KeyboardShortcuts.Recorder("Launch Courier:", name: .toggleCourier)
                    .accessibilityLabel("Courier hotkey recorder")
                    .accessibilityHint("Click, then press the key combination you want to use to open Courier")
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
                .accessibilityLabel("Reset hotkey to default")
                .accessibilityHint("Sets the hotkey back to Option+Space")
            }
            .padding(.horizontal, 40)

}
        .padding(40)
        .onAppear {
            hasShortcut = KeyboardShortcuts.getShortcut(for: .toggleCourier) != nil
        }
    }
}
