import SwiftUI

/// Root view hosted inside the launcher panel.
/// Placeholder — query input and service bar added in Phase 2.
struct LauncherView: View {
    let viewModel: LauncherViewModel

    var body: some View {
        VStack(spacing: 0) {
            Text("Courier")
                .font(.system(size: 15))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
        }
        .frame(width: 680)
    }
}
