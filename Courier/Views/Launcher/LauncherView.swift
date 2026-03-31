import SwiftUI

/// Root view hosted inside the launcher panel.
struct LauncherView: View {
    let viewModel: LauncherViewModel
    var onSubmit: (() -> Void)?
    var onDismiss: (() -> Void)?

    private let charLimit = 8000

    private var isOverLimit: Bool {
        viewModel.queryText.count > charLimit
    }

    var body: some View {
        VStack(spacing: 0) {
            // Query text input
            QueryInputView(
                text: Binding(
                    get: { viewModel.queryText },
                    set: { viewModel.queryText = $0 }
                ),
                height: Binding(
                    get: { viewModel.contentHeight },
                    set: { viewModel.contentHeight = $0 }
                ),
                onSubmit: { onSubmit?() },
                onDismiss: { onDismiss?() },
                viewModel: viewModel
            )
            .frame(height: viewModel.contentHeight)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, isOverLimit ? 4 : 0)

            // Inline char-limit warning
            if isOverLimit {
                Text("Query will be truncated to \(charLimit) characters")
                    .font(.system(size: 11))
                    .foregroundStyle(Color(nsColor: .systemOrange))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 6)
                    .transition(.opacity)
            }

            // Separator
            Rectangle()
                .fill(Color(nsColor: .separatorColor))
                .frame(height: 1)
                .padding(.horizontal, 8)

            // Service bar + Deliver button
            ServiceBar(
                viewModel: viewModel,
                disabledServices: viewModel.settings?.disabledServices ?? [],
                onSubmit: { onSubmit?() }
            )
        }
        .frame(width: 680)
        .animation(.easeInOut(duration: 0.15), value: isOverLimit)
    }
}
