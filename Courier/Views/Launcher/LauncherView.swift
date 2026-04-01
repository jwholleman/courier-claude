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
            VStack(spacing: 0) {
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
                .padding(.horizontal, LauncherTokens.Layout.inputHorizontalPadding)
                .padding(.top, LauncherTokens.Layout.inputTopPadding)
                .padding(.bottom, isOverLimit ? LauncherTokens.Layout.inputBottomPaddingWarning : LauncherTokens.Layout.inputBottomPadding)

                if isOverLimit {
                    Text("Query will be truncated to \(charLimit) characters")
                        .font(.system(size: LauncherTokens.Typography.warningSize, weight: .medium))
                        .foregroundStyle(Color(nsColor: .systemOrange))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, LauncherTokens.Layout.warningHorizontalPadding)
                        .padding(.bottom, LauncherTokens.Layout.warningBottomPadding)
                        .transition(.opacity)
                }
            }
            .background(inputSurface)
            .overlay {
                RoundedRectangle(cornerRadius: LauncherTokens.Layout.panelCornerRadius, style: .continuous)
                    .stroke(LauncherTokens.Color.inputBorder, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: LauncherTokens.Layout.panelCornerRadius, style: .continuous))

            ServiceBar(
                viewModel: viewModel,
                disabledServices: viewModel.settings?.disabledServices ?? [],
                onSubmit: { onSubmit?() }
            )
        }
        .frame(width: LauncherTokens.Layout.panelWidth)
        .padding(LauncherTokens.Layout.panelOuterPadding)
        .background(panelSurface)
        .animation(.easeInOut(duration: LauncherTokens.Motion.stateEase), value: isOverLimit)
    }

    private var inputSurface: some ShapeStyle {
        LinearGradient(
            colors: [
                Color(nsColor: LauncherTokens.Color.inputTop),
                Color(nsColor: LauncherTokens.Color.inputBottom)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var panelSurface: some ShapeStyle {
        LinearGradient(
            colors: [
                Color(nsColor: LauncherTokens.Color.panelTop),
                Color(nsColor: LauncherTokens.Color.panelBottom)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
