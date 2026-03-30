import SwiftUI

struct DeliverButton: View {
    let isEnabled: Bool
    let onDeliver: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onDeliver) {
            HStack(spacing: 6) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 13, weight: .medium))
                Text("Deliver")
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(isEnabled ? .white : Color(nsColor: .tertiaryLabelColor))
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isEnabled
                        ? Color(nsColor: .controlAccentColor).opacity(isHovered ? 0.85 : 1.0)
                        : Color(nsColor: .quaternaryLabelColor)
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .help("Deliver query")
        .accessibilityLabel("Deliver query")
        .accessibilityHint(isEnabled ? "Sends your query to the selected service" : "Enter a query first")
        .onHover { hovered in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovered = hovered
            }
        }
    }
}
