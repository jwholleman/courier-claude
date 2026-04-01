import SwiftUI
import KeyboardShortcuts

struct SettingsView: View {
    @Bindable var settings: AppSettings
    @State private var launchAtLogin: Bool = false
    @State private var loginItemError: String? = nil
    @State private var showResetConfirm = false
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

    private let llmServices: [ServiceType] = [.claude, .chatgpt, .gemini, .perplexity]
    private let searchServices: [ServiceType] = [.kagi, .google, .duckduckgo]

    private var enabledCount: Int {
        ServiceType.allCases.filter { !settings.disabledServices.contains($0) }.count
    }

    var body: some View {
        TabView {
            // MARK: - General tab (hotkey, startup, services)
            generalTab
                .tabItem { Label("General", systemImage: "gear") }

            // MARK: - Advanced tab
            advancedTab
                .tabItem { Label("Advanced", systemImage: "slider.horizontal.3") }
        }
        .frame(width: 560, height: 500)
        .onAppear {
            launchAtLogin = settings.launchAtLogin
            initSlashCommandTexts()
        }
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

    // MARK: - General tab (hotkey + startup + services combined)

    private var generalTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // Behavior (hotkey + launch at login)
                sectionHeader("Behavior")
                VStack(spacing: 1) {
                    HStack {
                        Text("Open on startup")
                            .font(.body)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Toggle("", isOn: $launchAtLogin)
                                .toggleStyle(.switch)
                                .labelsHidden()
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
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(Color(nsColor: .controlBackgroundColor))

                    HStack {
                        Text("Theme")
                            .font(.body)
                        Spacer()
                        Picker("", selection: $settings.theme) {
                            ForEach(AppTheme.allCases, id: \.rawValue) { t in
                                Text(t.displayName).tag(t)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 180)
                        .labelsHidden()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(Color(nsColor: .controlBackgroundColor))

                    HStack {
                        Text("Keyboard shortcut:")
                            .font(.body)
                        Spacer()
                        KeyboardShortcuts.Recorder("", name: .toggleCourier)
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

                // AI Assistants
                sectionHeader("AI Assistants")
                VStack(spacing: 1) {
                    ForEach(llmServices) { service in
                        llmServiceRow(for: service)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))

                // Search Engines
                sectionHeader("Search Engines")
                VStack(spacing: 1) {
                    ForEach(searchServices) { service in
                        searchServiceRow(for: service)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))

            }
            .padding(16)
        }
    }

    // MARK: - Service rows

    /// The currently active search engine (first enabled, fallback to .google).
    private var selectedSearchService: ServiceType {
        searchServices.first { !settings.disabledServices.contains($0) } ?? .google
    }

    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(.secondary)
            .padding(.top, 12)
            .padding(.bottom, 6)
            .padding(.horizontal, 4)
    }

    // LLM row: [toggle] [icon] [name] [spacer] [slash field]
    private func llmServiceRow(for service: ServiceType) -> some View {
        let isEnabled = !settings.disabledServices.contains(service)
        let canDisable = enabledCount > 1 || !isEnabled

        return HStack(spacing: 10) {
            Toggle("", isOn: Binding(
                get: { isEnabled },
                set: { enabled in
                    if enabled { settings.disabledServices.remove(service) }
                    else       { settings.disabledServices.insert(service) }
                }
            ))
            .disabled(!canDisable && isEnabled)
            .labelsHidden()

            Image(service.iconName, bundle: nil)
                .resizable()
                .renderingMode(.template)
                .frame(width: 16, height: 16)
                .foregroundStyle(isEnabled ? Color(nsColor: .controlAccentColor) : .secondary)

            Text(service.displayName)
                .font(.body)
                .lineLimit(1)

            Spacer(minLength: 8)

            TextField("", text: slashCommandBinding(for: service))
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12, design: .monospaced))
                .frame(width: 240)
                .disabled(!isEnabled)
                .opacity(isEnabled ? 1.0 : 0.4)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // Search row: [radio] [icon] [name] [spacer] [slash field]
    private func searchServiceRow(for service: ServiceType) -> some View {
        let isSelected = selectedSearchService == service

        return HStack(spacing: 10) {
            Button {
                // Select this engine, deselect all others
                for s in searchServices { settings.disabledServices.insert(s) }
                settings.disabledServices.remove(service)
            } label: {
                Image(systemName: isSelected ? "circle.inset.filled" : "circle")
                    .foregroundStyle(isSelected ? Color(nsColor: .controlAccentColor) : .secondary)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)

            Image(service.iconName, bundle: nil)
                .resizable()
                .renderingMode(.template)
                .frame(width: 16, height: 16)
                .foregroundStyle(isSelected ? Color(nsColor: .controlAccentColor) : .secondary)

            Text(service.displayName)
                .font(.body)
                .lineLimit(1)

            Spacer(minLength: 8)

            TextField("", text: slashCommandBinding(for: service))
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12, design: .monospaced))
                .frame(width: 240)
                .disabled(!isSelected)
                .opacity(isSelected ? 1.0 : 0.4)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Color(nsColor: .controlBackgroundColor))
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

            Section {
                Button("Reset All Settings to Defaults…") { showResetConfirm = true }
                    .foregroundStyle(.red)
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
        settings.theme = .system
        launchAtLogin = false
        try? LoginItemManager.shared.disable()
    }
}
