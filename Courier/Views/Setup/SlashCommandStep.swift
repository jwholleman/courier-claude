import SwiftUI

struct SlashCommandStep: View {
    @Bindable var settings: AppSettings
    @State private var launchAtLogin: Bool = false
    @State private var loginItemError: String? = nil

    var body: some View {
        VStack(spacing: 24) {
            Text("Almost Done")
                .font(.title.bold())

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Launch at Login")
                            .font(.body)
                        Text("Courier will start automatically when you log in.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $launchAtLogin)
                        .labelsHidden()
                        .accessibilityLabel("Launch at Login")
                        .accessibilityHint("Automatically start Courier when you log in to your Mac")
                        .onChange(of: launchAtLogin) { _, newValue in
                            settings.launchAtLogin = newValue
                            do {
                                if newValue {
                                    try LoginItemManager.shared.enable()
                                } else {
                                    try LoginItemManager.shared.disable()
                                }
                                loginItemError = nil
                            } catch {
                                loginItemError = "Could not update login item: \(error.localizedDescription)"
                                launchAtLogin = !newValue
                                settings.launchAtLogin = !newValue
                            }
                        }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))

                if let error = loginItemError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 4)
                        .accessibilityLabel("Error: \(error)")
                }
            }
            .padding(.horizontal, 32)

        }
        .padding(40)
        .onAppear {
            launchAtLogin = settings.launchAtLogin
        }
    }
}
