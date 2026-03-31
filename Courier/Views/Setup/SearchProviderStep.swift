import SwiftUI

struct SearchProviderStep: View {
    @Bindable var settings: AppSettings

    private let searchServices: [ServiceType] = [.kagi, .google, .duckduckgo]

    /// The currently selected search engine (first non-disabled one, defaulting to Google).
    private var selectedEngine: ServiceType {
        searchServices.first { !settings.disabledServices.contains($0) } ?? .google
    }

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("Choose Your Search Engine")
                    .font(.title2.bold())
                Text("Select one search engine for web queries.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 10) {
                ForEach(searchServices) { service in
                    SearchEngineRow(
                        service: service,
                        isSelected: selectedEngine == service
                    ) {
                        // Enable selected, disable others
                        for s in searchServices {
                            if s == service {
                                settings.disabledServices.remove(s)
                            } else {
                                settings.disabledServices.insert(s)
                            }
                        }
                        // Ensure last-used service fallback is still valid
                        if settings.disabledServices.contains(settings.lastUsedService) {
                            settings.lastUsedService = settings.effectiveSelectedService
                        }
                    }
                }
            }
            .padding(.horizontal, 32)
        }
        .padding(40)
    }
}

private struct SearchEngineRow: View {
    let service: ServiceType
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                Image(service.iconName, bundle: nil)
                    .resizable()
                    .renderingMode(.template)
                    .frame(width: 18, height: 18)
                    .foregroundStyle(isSelected ? Color(nsColor: .controlAccentColor) : .secondary)

                Text(service.displayName)
                    .font(.body)
                    .foregroundStyle(.primary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color(nsColor: .controlAccentColor))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(isSelected
                        ? Color(nsColor: .controlAccentColor).opacity(0.1)
                        : Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color(nsColor: .controlAccentColor).opacity(0.4) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
