import SwiftUI

struct ServiceBar: View {
    let viewModel: LauncherViewModel
    let disabledServices: Set<ServiceType>
    let onSubmit: () -> Void

    /// All enabled services in left-to-right display order — used for Cmd+number positions.
    private var orderedServices: [ServiceType] {
        ServiceType.displayOrder.filter { !disabledServices.contains($0) }
    }

    private var llmServices: [ServiceType] {
        ServiceType.displayOrder.filter { $0.category == .llm && !disabledServices.contains($0) }
    }

    private var searchServices: [ServiceType] {
        ServiceType.displayOrder.filter { $0.category == .search && !disabledServices.contains($0) }
    }

    private var isDeliverEnabled: Bool {
        !viewModel.isSlashMode &&
        !viewModel.queryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        HStack(spacing: 0) {
            // LLM service buttons
            HStack(spacing: 16) {
                ForEach(llmServices) { service in
                    ServiceButton(
                        service: service,
                        isSelected: viewModel.selectedService == service,
                        isSlashMode: viewModel.isSlashMode,
                        slashPrefix: viewModel.slashPrefix,
                        isCmdMode: viewModel.isCmdMode,
                        cmdPosition: (orderedServices.firstIndex(of: service) ?? 0) + 1
                    ) {
                        viewModel.selectService(service)
                    }
                }
            }

            // Divider between LLMs and search engines (only if both groups have members)
            if !llmServices.isEmpty && !searchServices.isEmpty {
                Rectangle()
                    .fill(Color(nsColor: .separatorColor))
                    .frame(width: 1, height: 24)
                    .padding(.horizontal, 8)
            }

            // Search service buttons
            HStack(spacing: 16) {
                ForEach(searchServices) { service in
                    ServiceButton(
                        service: service,
                        isSelected: viewModel.selectedService == service,
                        isSlashMode: viewModel.isSlashMode,
                        slashPrefix: viewModel.slashPrefix,
                        isCmdMode: viewModel.isCmdMode,
                        cmdPosition: (orderedServices.firstIndex(of: service) ?? 0) + 1
                    ) {
                        viewModel.selectService(service)
                    }
                }
            }

            Spacer()

            DeliverButton(isEnabled: isDeliverEnabled, onDeliver: onSubmit)
        }
        .padding(.top, 20)
    }
}
