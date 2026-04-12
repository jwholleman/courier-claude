import SwiftUI

struct ServiceSelectionStep: View {
    @Bindable var settings: AppSettings
    @Environment(\.colorScheme) private var colorScheme

    // Ordered for display: 3 per row
    private let allServices: [ServiceType] = [
        .claude, .chatgpt, .gemini,
        .perplexity, .claudeCode, .kagi,
        .google, .duckduckgo, .youtube
    ]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    var body: some View {
        VStack(spacing: 20) {
            Text("Select services you use")
                .font(.title.bold())

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(allServices) { service in
                    ServiceTile(
                        service: service,
                        isEnabled: !settings.disabledServices.contains(service),
                        colorScheme: colorScheme
                    ) {
                        toggle(service)
                    }
                }
            }
            .padding(.horizontal, 32)
        }
        .padding(40)
    }

    private func toggle(_ service: ServiceType) {
        if settings.disabledServices.contains(service) {
            settings.disabledServices.remove(service)
        } else {
            // Don't allow disabling if it's the last enabled service overall
            let enabledCount = allServices.filter { !settings.disabledServices.contains($0) }.count
            if enabledCount > 1 {
                settings.disabledServices.insert(service)
            }
        }
    }
}

private struct ServiceTile: View {
    let service: ServiceType
    let isEnabled: Bool
    let colorScheme: ColorScheme
    let onTap: () -> Void

    // ChatGPT icon is white — use template+primary so it inverts with color scheme
    private var usesChatGPTOverride: Bool { service == .chatgpt }
    private var usesKagiDarkOverride: Bool { service == .kagi && colorScheme == .dark }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Image(service.iconName, bundle: nil)
                    .resizable()
                    .renderingMode((usesChatGPTOverride || usesKagiDarkOverride) ? .template : .original)
                    .frame(width: 28, height: 28)
                    .foregroundStyle(iconForegroundColor)
                    .accessibilityHidden(true)

                Text(service.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(
                        isEnabled ? Color(nsColor: .controlAccentColor) : Color.clear,
                        lineWidth: 2
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(service.displayName)
        .accessibilityHint(isEnabled ? "Tap to deselect" : "Tap to select")
        .accessibilityValue(isEnabled ? "Selected" : "Not selected")
    }

    private var iconForegroundColor: Color {
        if usesKagiDarkOverride {
            return .white
        }
        if usesChatGPTOverride {
            return .primary
        }
        return .clear
    }
}
