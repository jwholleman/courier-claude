import SwiftUI

struct DeliverButton: View {
    let isEnabled: Bool
    let onDeliver: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onDeliver) {
            HStack(spacing: LauncherTokens.Layout.deliverSpacing) {
                Image("MenuBarIcon", bundle: nil)
                    .resizable()
                    .renderingMode(.template)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: LauncherTokens.Typography.deliverSize, height: LauncherTokens.Typography.deliverSize)
                Text("Deliver")
                    .font(.system(size: LauncherTokens.Typography.deliverSize, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(isEnabled ? .white : Color(nsColor: .tertiaryLabelColor))
            .padding(.horizontal, LauncherTokens.Layout.deliverHorizontalPadding)
            .frame(height: LauncherTokens.Layout.deliverButtonHeight)
            .background(
                RoundedRectangle(cornerRadius: LauncherTokens.Layout.controlCornerRadius, style: .continuous)
                    .fill(backgroundFill)
            )
            .overlay {
                RoundedRectangle(cornerRadius: LauncherTokens.Layout.controlCornerRadius, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .help("Deliver query")
        .accessibilityLabel("Deliver query")
        .accessibilityHint(isEnabled ? "Sends your query to the selected service" : "Enter a query first")
        .padding(.top, LauncherTokens.Layout.deliverTopMargin)
        .onHover { hovered in
            withAnimation(.easeInOut(duration: LauncherTokens.Motion.quickEase)) {
                isHovered = hovered
            }
        }
    }

    private var backgroundFill: Color {
        if isEnabled {
            return Color(nsColor: .controlAccentColor).opacity(isHovered ? 0.88 : 0.98)
        }
        return LauncherTokens.Color.deliverDisabledBackground
    }

    private var borderColor: Color {
        if isEnabled {
            return isHovered ? LauncherTokens.Color.deliverEnabledBorderHover : LauncherTokens.Color.deliverEnabledBorder
        }
        return LauncherTokens.Color.deliverDisabledBorder
    }
}
