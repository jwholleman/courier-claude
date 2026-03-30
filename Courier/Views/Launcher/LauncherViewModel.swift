import AppKit
import Observation

@Observable
@MainActor
final class LauncherViewModel {
    var queryText: String = ""
    var contentHeight: CGFloat = 80
    var selectedService: ServiceType = .claude
    var isSlashMode: Bool = false
    var slashPrefix: String = ""
    var hasSubmitted: Bool = false

    // Injected at init from AppSettings so selection persists across launches
    var settings: AppSettings?

    // Set by QueryInputView Coordinator during makeNSView.
    // CRITICAL: @ObservationIgnored is required — @Observable does not support
    // observing weak references and will fail to compile without this annotation.
    @ObservationIgnored weak var queryTextView: NSTextView?

    func clearQuery() {
        queryText = ""
        contentHeight = 80
        isSlashMode = false
        slashPrefix = ""
        hasSubmitted = false
        // Restore last-used service from settings (always-selected invariant)
        if let settings {
            selectedService = settings.effectiveSelectedService
        }
    }

    func selectService(_ service: ServiceType) {
        selectedService = service
        settings?.lastUsedService = service
    }

    func cycleService(direction: Int, disabledServices: Set<ServiceType> = []) {
        let enabled = ServiceType.displayOrder.filter { !disabledServices.contains($0) }
        guard let currentIndex = enabled.firstIndex(of: selectedService) else { return }
        let newIndex = (currentIndex + direction + enabled.count) % enabled.count
        selectService(enabled[newIndex])
    }
}
