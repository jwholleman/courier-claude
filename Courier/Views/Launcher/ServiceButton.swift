import SwiftUI

struct ServiceButton: View {
    @Environment(\.colorScheme) private var colorScheme

    let service: ServiceType
    let isSelected: Bool
    let isSlashMode: Bool
    let slashPrefix: String
    let isCmdMode: Bool
    let cmdPosition: Int
    let onSelect: () -> Void

    @State private var isHovered = false

    private var showsTooltip: Bool {
        isHovered || isCmdMode || isSlashMode
    }

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

    private var showsBrandColor: Bool {
        isSelected || isHovered
    }

    private var iconAssetName: String {
        if !showsBrandColor {
            switch service {
            case .duckduckgo:
                return "duckduckgoNegative"
            case .claudeCode:
                return "claudeCodeNegative"
            case .youtube:
                return "youtubeNegative"
            default:
                break
            }
        }
        return service.iconName
    }

    private var usesChatGPTLightBrandOverride: Bool {
        service == .chatgpt && showsBrandColor && colorScheme == .light
    }

    private var usesKagiDarkBrandOverride: Bool {
        service == .kagi && showsBrandColor && colorScheme == .dark
    }

    var body: some View {
        Button(action: onSelect) {
            Group {
                if isCmdMode {
                    Text("⌘\(cmdPosition)")
                        .font(.system(size: LauncherTokens.Typography.shortcutSize, weight: .semibold, design: .rounded))
                        .foregroundStyle(isSelected ? Color(nsColor: .controlAccentColor) : Color(nsColor: .labelColor))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                } else if isSlashMode {
                    Text(shortCommand)
                        .font(.system(size: LauncherTokens.Typography.shortcutSize, weight: .semibold, design: .rounded))
                        .foregroundStyle(matchesPrefix ? Color(nsColor: .labelColor) : Color(nsColor: .secondaryLabelColor))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                } else {
                    Image(iconAssetName, bundle: nil)
                        .resizable()
                        .renderingMode((showsBrandColor || (service == .kagi && isSelected)) && !usesChatGPTLightBrandOverride && !usesKagiDarkBrandOverride ? .original : .template)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: LauncherTokens.Layout.iconSize, height: LauncherTokens.Layout.iconSize)
                        .foregroundStyle(iconForegroundColor)
                        .saturation(showsBrandColor ? 1 : 0)
                        .brightness(showsBrandColor ? 0 : 0)
                        .opacity(showsBrandColor ? 1 : 0.95)
                        .scaleEffect(service == .gemini ? 1.18 : 1.0)
                }
            }
            .frame(width: LauncherTokens.Layout.buttonSize, height: LauncherTokens.Layout.buttonSize)
            .background(backgroundFill)
            .overlay {
                RoundedRectangle(cornerRadius: LauncherTokens.Layout.controlCornerRadius, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: LauncherTokens.Layout.controlCornerRadius, style: .continuous))
            .opacity(isSlashMode && !isCmdMode && !matchesPrefix ? 0.4 : 1.0)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isSlashMode
            ? "\(service.displayName) \(matchesPrefix ? "matching" : "not matching")"
            : "Send to \(service.displayName)")
        .overlay(alignment: .bottom) {
            if showsTooltip {
                Text(service.displayName)
                    .font(.system(size: LauncherTokens.Typography.tooltipSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                    .fixedSize()
                    .offset(y: LauncherTokens.Layout.tooltipOffsetY)
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }
        }
        .onHover { hovered in
            withAnimation(.easeInOut(duration: LauncherTokens.Motion.quickEase)) {
                isHovered = hovered
            }
        }
        .zIndex(showsTooltip ? 1 : 0)
    }

    private var backgroundFill: Color {
        if isSlashMode && matchesPrefix {
            return Color(nsColor: .controlAccentColor).opacity(isHovered ? 0.24 : 0.18)
        }
        if isSelected && isHovered { return Color(nsColor: .controlAccentColor).opacity(0.22) }
        if isSelected             { return Color(nsColor: .controlAccentColor).opacity(0.16) }
        if isHovered              { return LauncherTokens.Color.serviceBackgroundHover }
        return LauncherTokens.Color.serviceBackgroundDefault
    }

    private var borderColor: Color {
        if isSelected || (isSlashMode && matchesPrefix) {
            return Color(nsColor: .controlAccentColor).opacity(0.55)
        }
        if isHovered {
            return LauncherTokens.Color.serviceBorderHover
        }
        return LauncherTokens.Color.serviceBorderDefault
    }

    private var iconForegroundColor: Color {
        if usesKagiDarkBrandOverride {
            return .white
        }
        if service == .kagi && isSelected {
            return LauncherTokens.Color.kagiSelected
        }
        if usesChatGPTLightBrandOverride {
            return Color.black
        }
        return Color(nsColor: LauncherTokens.Color.placeholder)
    }
}
