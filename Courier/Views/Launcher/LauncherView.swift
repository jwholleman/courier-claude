import SwiftUI

/// Root view hosted inside the launcher panel.
struct LauncherView: View {
    let viewModel: LauncherViewModel

    var body: some View {
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
                onSubmit: {},    // Wired in Task 2.1d
                onDismiss: {},   // Wired in Task 2.4
                viewModel: viewModel
            )
            .frame(height: viewModel.contentHeight)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(width: 680)
    }
}
