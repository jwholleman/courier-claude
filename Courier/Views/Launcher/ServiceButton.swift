import SwiftUI

struct ServiceButton: View {
    let service: ServiceType
    let isSelected: Bool
    let onSelect: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            Image(service.iconName, bundle: nil)
                .resizable()
                .renderingMode(.template)
                .frame(width: 20, height: 20)
                .foregroundStyle(isSelected ? Color(nsColor: .controlAccentColor) : .primary)
                .frame(width: 36, height: 36)
                .background(backgroundFill)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .help("Send to \(service.displayName)")
        .accessibilityLabel("Send to \(service.displayName)")
        .onHover { hovered in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovered = hovered
            }
        }
    }

    private var backgroundFill: Color {
        if isSelected && isHovered {
            return Color(nsColor: .controlAccentColor).opacity(0.25)
        } else if isSelected {
            return Color(nsColor: .controlAccentColor).opacity(0.2)
        } else if isHovered {
            return Color(nsColor: .controlAccentColor).opacity(0.1)
        }
        return .clear
    }
}
