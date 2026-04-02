import SwiftUI

struct ServiceBar: View {
    let viewModel: LauncherViewModel
    @Bindable var settings: AppSettings
    let onSubmit: () -> Void

    /// All enabled services in left-to-right display order — used for Cmd+number positions.
    private var orderedServices: [ServiceType] {
        settings.enabledServices
    }

    private var isDeliverEnabled: Bool {
        !viewModel.isSlashMode &&
        !viewModel.queryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var selectedService: ServiceType {
        let fallback = orderedServices.first ?? viewModel.selectedService
        let resolved = orderedServices.contains(viewModel.selectedService) ? viewModel.selectedService : fallback
        if resolved != viewModel.selectedService {
            DispatchQueue.main.async {
                viewModel.selectService(resolved)
            }
        }
        return resolved
    }

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 16) {
                ForEach(orderedServices) { service in
                    ServiceButton(
                        service: service,
                        isSelected: selectedService == service,
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
