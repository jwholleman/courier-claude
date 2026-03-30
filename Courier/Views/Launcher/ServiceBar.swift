import SwiftUI

struct ServiceBar: View {
    let viewModel: LauncherViewModel
    let disabledServices: Set<ServiceType>
    let onSubmit: () -> Void

    private var llmServices: [ServiceType] {
        ServiceType.displayOrder.filter { $0.category == .llm && !disabledServices.contains($0) }
    }

    private var searchServices: [ServiceType] {
        ServiceType.displayOrder.filter { $0.category == .search && !disabledServices.contains($0) }
    }

    private var isDeliverEnabled: Bool {
        !viewModel.queryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        HStack(spacing: 0) {
            // LLM service buttons
            HStack(spacing: 8) {
                ForEach(llmServices) { service in
                    ServiceButton(
                        service: service,
                        isSelected: viewModel.selectedService == service
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
            HStack(spacing: 8) {
                ForEach(searchServices) { service in
                    ServiceButton(
                        service: service,
                        isSelected: viewModel.selectedService == service
                    ) {
                        viewModel.selectService(service)
                    }
                }
            }

            Spacer()

            DeliverButton(isEnabled: isDeliverEnabled, onDeliver: onSubmit)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
        .onKeyPress(.leftArrow) {
            cycleService(direction: -1)
            return .handled
        }
        .onKeyPress(.rightArrow) {
            cycleService(direction: 1)
            return .handled
        }
    }

    private func cycleService(direction: Int) {
        let enabled = ServiceType.displayOrder.filter { !disabledServices.contains($0) }
        guard let currentIndex = enabled.firstIndex(of: viewModel.selectedService) else { return }
        let newIndex = (currentIndex + direction + enabled.count) % enabled.count
        viewModel.selectService(enabled[newIndex])
    }
}
