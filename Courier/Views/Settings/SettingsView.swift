import SwiftUI
import KeyboardShortcuts
import UniformTypeIdentifiers

struct SettingsView: View {
    @Bindable var settings: AppSettings
    @State private var launchAtLogin: Bool = false
    @State private var loginItemError: String? = nil
    @State private var showResetConfirm = false
    @State private var draggedService: ServiceType? = nil
    @State private var currentDropTarget: ServiceType? = nil
    @State private var hoveredService: ServiceType? = nil
    @State private var draftServiceOrder: [ServiceType] = []
    /// Local text buffer for slash command fields — avoids cursor-reset on every keystroke.
    @State private var slashCommandTexts: [String: String] = [:]

    private var chatGPTInstalled: Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.openai.chat") != nil
    }

    private var hotkeyConflictWarning: String? {
        let shortcut = KeyboardShortcuts.getShortcut(for: .toggleCourier)
        let isOptionSpace = shortcut?.modifiers == .option && shortcut?.key == .space
        guard isOptionSpace && chatGPTInstalled else { return nil }
        return "Global shortcuts can conflict with other apps. Change it here or in the conflicting app."
    }

    private var enabledCount: Int {
        settings.enabledServices.count
    }

    private var detectedDesktopApps: [ServiceType] {
        ServiceType.desktopAppServices.filter(\.isDesktopAppDetected)
    }

    var body: some View {
        generalTab
        .frame(width: 560, height: 500)
        .onAppear {
            launchAtLogin = settings.launchAtLogin
            draftServiceOrder = settings.orderedServices
            initSlashCommandTexts()
        }
        .onChange(of: settings.serviceOrder) { _, newValue in
            guard draggedService == nil else { return }
            draftServiceOrder = newValue
        }
        .confirmationDialog(
            "Reset all settings to defaults?",
            isPresented: $showResetConfirm,
            titleVisibility: .visible
        ) {
            Button("Reset", role: .destructive) { resetToDefaults() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone. Your service selections, hotkey, and slash commands will all be reset.")
        }
    }

    // MARK: - Settings Content

    private var generalTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // Behavior (hotkey + launch at login)
                sectionHeader("Behavior")
                VStack(spacing: 1) {
                    HStack {
                        Text("Theme")
                            .font(.body)
                            .accessibilityHidden(true)
                        Spacer()
                        Picker("", selection: $settings.theme) {
                            ForEach(AppTheme.allCases, id: \.rawValue) { t in
                                Text(t.displayName).tag(t)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 180)
                        .labelsHidden()
                        .accessibilityLabel("Theme")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(Color(nsColor: .controlBackgroundColor))

                    HStack {
                        Text("Open on startup")
                            .font(.body)
                            .accessibilityHidden(true)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Toggle("", isOn: $launchAtLogin)
                                .toggleStyle(.switch)
                                .labelsHidden()
                                .accessibilityLabel("Open on startup")
                                .onChange(of: launchAtLogin) { _, newValue in
                                    settings.launchAtLogin = newValue
                                    do {
                                        if newValue { try LoginItemManager.shared.enable() }
                                        else        { try LoginItemManager.shared.disable() }
                                        loginItemError = nil
                                    } catch {
                                        loginItemError = error.localizedDescription
                                        launchAtLogin = !newValue
                                        settings.launchAtLogin = !newValue
                                    }
                                }
                            if let err = loginItemError {
                                Text(err)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                                    .accessibilityLabel("Error: \(err)")
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(Color(nsColor: .controlBackgroundColor))

                    HStack {
                        Text("Use desktop apps")
                            .font(.body)
                            .accessibilityHidden(true)
                        Spacer()
                        Toggle("", isOn: $settings.useDesktopApps)
                            .toggleStyle(.switch)
                            .labelsHidden()
                            .accessibilityLabel("Use desktop apps")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(Color(nsColor: .controlBackgroundColor))

                    if !detectedDesktopApps.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(detectedDesktopApps) { service in
                                Label("\(service.displayName) is detected on your computer", systemImage: "info.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(nsColor: .controlBackgroundColor))
                    }

                    HStack {
                        Text("Keyboard shortcut:")
                            .font(.body)
                            .accessibilityHidden(true)
                        Spacer()
                        KeyboardShortcuts.Recorder("", name: .toggleCourier)
                            .accessibilityLabel("Courier keyboard shortcut")
                            .accessibilityHint("Click then press the key combination you want to use to open Courier")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(Color(nsColor: .controlBackgroundColor))

                    if let warning = hotkeyConflictWarning {
                        Label(warning, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(nsColor: .controlBackgroundColor))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))

                // Services
                sectionHeader("Services")
                VStack(spacing: 1) {
                    ForEach(draftServiceOrder) { service in
                        serviceRow(for: service)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))

                // Reset
                sectionHeader("Reset")
                VStack(spacing: 1) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Reset all settings")
                                .font(.body)
                            Text("Restore Courier's default configuration.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Reset All Settings…") { showResetConfirm = true }
                            .foregroundStyle(.red)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(Color(nsColor: .controlBackgroundColor))
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))

            }
            .padding(16)
        }
    }

    // MARK: - Service rows

    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(.secondary)
            .padding(.top, 12)
            .padding(.bottom, 6)
            .padding(.horizontal, 4)
            .accessibilityAddTraits(.isHeader)
    }

    // Service row: [toggle] [icon] [name] [spacer] [slash field]
    private func serviceRow(for service: ServiceType) -> some View {
        let isEnabled = !settings.disabledServices.contains(service)
        let canDisable = enabledCount > 1 || !isEnabled

        return HStack(spacing: 10) {
            dragHandle(for: service)
                .help("Drag to reorder services")

            Toggle("", isOn: Binding(
                get: { isEnabled },
                set: { enabled in
                    if enabled { settings.disabledServices.remove(service) }
                    else       { settings.disabledServices.insert(service) }
                }
            ))
            .disabled(!canDisable && isEnabled)
            .labelsHidden()
            .accessibilityLabel(isEnabled ? "\(service.displayName), enabled" : "\(service.displayName), disabled")
            .accessibilityHint(canDisable ? "Toggle to enable or disable \(service.displayName)" : "Cannot disable — at least one service must remain enabled")

            Image(service.settingsIconName, bundle: nil)
                .resizable()
                .renderingMode(.template)
                .frame(width: 16, height: 16)
                .foregroundStyle(isEnabled ? Color(nsColor: .controlAccentColor) : .secondary)
                .accessibilityHidden(true)

            Text(service.displayName)
                .font(.body)
                .lineLimit(1)
                .accessibilityHidden(true)

            Spacer(minLength: 8)

            TextField("", text: slashCommandBinding(for: service))
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12, design: .monospaced))
                .frame(width: 240)
                .disabled(!isEnabled)
                .opacity(isEnabled ? 1.0 : 0.4)
                .accessibilityLabel("Slash commands for \(service.displayName)")
                .accessibilityHint("Comma-separated slash commands, e.g. /claude, /ai. Leave empty to use defaults.")
        }
        .padding(.leading, 4)
        .padding(.trailing, 12)
        .padding(.vertical, 9)
        .background(Color(nsColor: .controlBackgroundColor))
        .contentShape(Rectangle())
        .onHover { isHovered in
            withAnimation(.easeInOut(duration: 0.12)) {
                hoveredService = isHovered ? service : (hoveredService == service ? nil : hoveredService)
            }
        }
        .onDrop(
            of: [UTType.text],
            delegate: ServiceRowDropDelegate(
                destination: service,
                settings: settings,
                services: $draftServiceOrder,
                persistedServices: settings.orderedServices,
                draggedService: $draggedService,
                currentDropTarget: $currentDropTarget
            )
        )
    }

    private func dragHandle(for service: ServiceType) -> some View {
        VStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { _ in
                HStack(spacing: 3) {
                    Circle()
                        .frame(width: 3, height: 3)
                    Circle()
                        .frame(width: 3, height: 3)
                }
            }
        }
        .foregroundStyle(.secondary)
        .frame(width: 18, height: 20)
        .opacity((hoveredService == service || draggedService == service) ? 1 : 0)
        .contentShape(Rectangle())
        .accessibilityElement()
        .accessibilityLabel("Reorder \(service.displayName)")
        .accessibilityHint("Drag to change the position of \(service.displayName) in the launcher")
        .onDrag {
            draggedService = service
            currentDropTarget = nil
            return NSItemProvider(object: service.rawValue as NSString)
        }
    }

    // MARK: - Slash command binding helpers

    private func initSlashCommandTexts() {
        for service in ServiceType.allCases {
            let cmds = settings.customSlashCommands[service.rawValue]
                ?? SlashCommand.all.filter { $0.serviceType == service }.map { $0.command }
            slashCommandTexts[service.rawValue] = cmds.joined(separator: ", ")
        }
    }

    private func slashCommandBinding(for service: ServiceType) -> Binding<String> {
        Binding(
            get: { slashCommandTexts[service.rawValue] ?? "" },
            set: { newValue in
                slashCommandTexts[service.rawValue] = newValue
                let parsed = newValue
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
                    .filter { $0.hasPrefix("/") }
                settings.customSlashCommands[service.rawValue] = parsed.isEmpty ? nil : parsed
            }
        )
    }

    // MARK: - Reset

    private func resetToDefaults() {
        KeyboardShortcuts.setShortcut(.init(.space, modifiers: .option), for: .toggleCourier)
        settings.disabledServices = []
        settings.customSlashCommands = [:]
        settings.keystrokeOverrides = [:]
        settings.serviceOrder = ServiceType.displayOrder
        draftServiceOrder = ServiceType.displayOrder
        settings.lastUsedService = settings.orderedServices.first ?? .claude
        settings.launchAtLogin = false
        settings.theme = .system
        launchAtLogin = false
        try? LoginItemManager.shared.disable()
    }
}

private struct ServiceRowDropDelegate: DropDelegate {
    let destination: ServiceType
    let settings: AppSettings
    @Binding var services: [ServiceType]
    let persistedServices: [ServiceType]
    @Binding var draggedService: ServiceType?
    @Binding var currentDropTarget: ServiceType?

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func dropEntered(info: DropInfo) {
        guard let draggedService,
              draggedService != destination,
              currentDropTarget != destination,
              let sourceIndex = services.firstIndex(of: draggedService),
              let destinationIndex = services.firstIndex(of: destination) else {
            return
        }

        currentDropTarget = destination
        let adjustedDestination = destinationIndex > sourceIndex ? destinationIndex + 1 : destinationIndex
        guard sourceIndex != adjustedDestination else { return }

        withAnimation(.interactiveSpring(response: 0.28, dampingFraction: 0.92, blendDuration: 0.16)) {
            let movedService = services.remove(at: sourceIndex)
            let targetIndex = min(max(adjustedDestination, 0), services.count)
            services.insert(movedService, at: targetIndex)
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        if services != persistedServices {
            settings.serviceOrder = services
        }
        currentDropTarget = nil
        draggedService = nil
        return true
    }

    func dropExited(info: DropInfo) {
        if draggedService == nil {
            services = persistedServices
        }
        currentDropTarget = nil
    }
}
