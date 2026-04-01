import SwiftUI

struct ServiceButton: View {
    let service: ServiceType
    let isSelected: Bool
    let isSlashMode: Bool
    let slashPrefix: String
    let isCmdMode: Bool
    let cmdPosition: Int
    let onSelect: () -> Void

    @State private var isHovered = false

    /// The shortest slash command for this service — shown in slash mode overlay.
    private var shortCommand: String {
        SlashCommand.all
            .filter { $0.serviceType == service }
            .map { $0.command }
            .min(by: { $0.count < $1.count }) ?? "/?"
    }

    /// Whether this service has any command matching the current slash prefix.
    private var matchesPrefix: Bool {
        guard isSlashMode, !slashPrefix.isEmpty else { return false }
        return SlashCommand.all.contains {
            $0.serviceType == service && $0.command.hasPrefix(slashPrefix)
        }
    }

    var body: some View {
        Button(action: onSelect) {
            Group {
                if isCmdMode {
                    Text("⌘\(cmdPosition)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color(nsColor: .labelColor))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                } else if isSlashMode {
                    Text(shortCommand)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(matchesPrefix ? Color(nsColor: .labelColor) : Color(nsColor: .secondaryLabelColor))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                } else {
                    Image(service.iconName, bundle: nil)
                        .resizable()
                        .renderingMode(.template)
                        .frame(width: 20, height: 20)
                        .foregroundStyle(isSelected ? Color(nsColor: .controlAccentColor) : .primary)
                }
            }
            .frame(width: 36, height: 36)
            .background(backgroundFill)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .opacity(isSlashMode && !isCmdMode && !matchesPrefix ? 0.4 : 1.0)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isSlashMode
            ? "\(service.displayName) \(matchesPrefix ? "matching" : "not matching")"
            : "Send to \(service.displayName)")
        .overlay(alignment: .bottom) {
            if isHovered && !isSlashMode {
                Text(service.displayName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                    .fixedSize()
                    .offset(y: 18)
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }
        }
        .onHover { hovered in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovered = hovered
            }
        }
        .zIndex(isHovered ? 1 : 0)
    }

    private var backgroundFill: Color {
        if isSlashMode && matchesPrefix {
            return Color(nsColor: .controlAccentColor).opacity(isHovered ? 0.25 : 0.2)
        }
        if isSelected && isHovered { return Color(nsColor: .controlAccentColor).opacity(0.25) }
        if isSelected             { return Color(nsColor: .controlAccentColor).opacity(0.2) }
        if isHovered              { return Color(nsColor: .controlAccentColor).opacity(0.1) }
        return .clear
    }
}
