import SwiftUI
import KeyboardShortcuts

struct SettingsView: View {
    @Bindable var settings: AppSettings
    @State private var launchAtLogin: Bool = false
    @State private var loginItemError: String? = nil
    @State private var showResetConfirm = false

    private var chatGPTInstalled: Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.openai.chat") != nil
    }

    private var hotkeyConflictWarning: String? {
        let shortcut = KeyboardShortcuts.getShortcut(for: .toggleCourier)
        let isOptionSpace = shortcut?.modifiers == .option && shortcut?.key == .space
        guard isOptionSpace && chatGPTInstalled else { return nil }
        return "ChatGPT desktop also uses ⌥Space — pressing it will open both launchers. Change your hotkey above to avoid the conflict."
    }

    private let llmServices: [ServiceType] = [.claude, .chatgpt, .gemini, .perplexity]
    private let searchServices: [ServiceType] = [.kagi, .google, .duckduckgo]

    private var enabledCount: Int {
        ServiceType.allCases.filter { !settings.disabledServices.contains($0) }.count
    }

    var body: some View {
        TabView {
            // MARK: - General tab
            generalTab
                .tabItem { Label("General", systemImage: "gear") }

            // MARK: - Services tab
            servicesTab
                .tabItem { Label("Services", systemImage: "app.badge") }

            // MARK: - Shortcuts tab
            shortcutsTab
                .tabItem { Label("Shortcuts", systemImage: "keyboard") }

            // MARK: - Advanced tab
            advancedTab
                .tabItem { Label("Advanced", systemImage: "slider.horizontal.3") }
        }
        .frame(width: 520, height: 400)
        .onAppear { launchAtLogin = settings.launchAtLogin }
    }

    // MARK: - General tab

    private var generalTab: some View {
        Form {
            Section("Hotkey") {
                KeyboardShortcuts.Recorder("Launch Courier:", name: .toggleCourier)
                Button("Reset to Default (⌥Space)") {
                    KeyboardShortcuts.setShortcut(.init(.space, modifiers: .option), for: .toggleCourier)
                }
                .buttonStyle(.bordered)
                if let warning = hotkeyConflictWarning {
                    Label(warning, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Section("Startup") {
                Toggle("Launch at Login", isOn: $launchAtLogin)
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
                    Text(err).font(.caption).foregroundStyle(.red)
                }
            }

            Section {
                Button("Reset All Settings to Defaults…") { showResetConfirm = true }
                    .foregroundStyle(.red)
            }
        }
        .formStyle(.grouped)
        .confirmationDialog(
            "Reset all settings to defaults?",
            isPresented: $showResetConfirm,
            titleVisibility: .visible
        ) {
            Button("Reset", role: .destructive) { resetToDefaults() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone. Your service selections, hotkey, slash commands, and keystroke config will all be reset.")
        }
    }

    // MARK: - Services tab

    private var servicesTab: some View {
        Form {
            Section("AI Assistants") {
                ForEach(llmServices) { service in
                    ServiceToggleRow(
                        service: service,
                        isEnabled: !settings.disabledServices.contains(service),
                        canDisable: enabledCount > 1 || settings.disabledServices.contains(service)
                    ) { enabled in
                        if enabled { settings.disabledServices.remove(service) }
                        else       { settings.disabledServices.insert(service) }
                    }
                }
            }

            Section("Search Engines") {
                ForEach(searchServices) { service in
                    ServiceToggleRow(
                        service: service,
                        isEnabled: !settings.disabledServices.contains(service),
                        canDisable: enabledCount > 1 || settings.disabledServices.contains(service)
                    ) { enabled in
                        if enabled { settings.disabledServices.remove(service) }
                        else       { settings.disabledServices.insert(service) }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Shortcuts tab

    private var shortcutsTab: some View {
        Form {
            Section("Slash Commands") {
                ForEach(ServiceType.displayOrder.filter { !settings.disabledServices.contains($0) }) { service in
                    HStack {
                        Image(service.iconName, bundle: nil)
                            .resizable().renderingMode(.template)
                            .frame(width: 16, height: 16)
                            .foregroundStyle(.secondary)
                        Text(service.displayName)
                        Spacer()
                        let cmds = settings.customSlashCommands[service.rawValue]
                            ?? SlashCommand.all.filter { $0.serviceType == service }.map { $0.command }
                        Text(cmds.joined(separator: ", "))
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Section {
                Text("To edit slash commands, open Setup again from the menu bar.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Advanced tab

    private var advancedTab: some View {
        Form {
            Section("Native App Keystroke") {
                Text("Configure how Courier opens a new conversation in each app before pasting. Change this if an app update changed its keyboard shortcut.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(llmServices) { service in
                    if settings.disabledServices.contains(service) { EmptyView() } else {
                        Picker(service.displayName, selection: Binding(
                            get: {
                                settings.keystrokeOverrides[service.rawValue]
                                    ?? service.defaultNewConversationKeystroke.rawValue
                            },
                            set: { settings.keystrokeOverrides[service.rawValue] = $0 }
                        )) {
                            ForEach(LLMKeystroke.allCases, id: \.rawValue) { k in
                                Text(k.displayName).tag(k.rawValue)
                            }
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Reset

    private func resetToDefaults() {
        KeyboardShortcuts.setShortcut(.init(.space, modifiers: .option), for: .toggleCourier)
        settings.disabledServices = []
        settings.customSlashCommands = [:]
        settings.keystrokeOverrides = [:]
        settings.lastUsedService = .claude
        settings.launchAtLogin = false
        launchAtLogin = false
        try? LoginItemManager.shared.disable()
    }
}
