import SwiftUI

struct SlashCommandStep: View {
    @Bindable var settings: AppSettings
    @State private var launchAtLogin: Bool = false
    @State private var loginItemError: String? = nil

    /// Effective slash commands per service — custom overrides or defaults.
    @State private var commandMap: [ServiceType: [String]] = [:]
    @State private var duplicateError: String? = nil

    private var enabledServices: [ServiceType] {
        ServiceType.displayOrder.filter { !settings.disabledServices.contains($0) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("Slash Commands & Startup")
                        .font(.title2.bold())
                    Text("Customize how you switch services, and whether Courier launches at login.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                // Launch at login toggle
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Launch at Login")
                                .font(.body)
                            Text("Courier will start automatically when you log in.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: $launchAtLogin)
                            .labelsHidden()
                            .onChange(of: launchAtLogin) { _, newValue in
                                settings.launchAtLogin = newValue
                                do {
                                    if newValue {
                                        try LoginItemManager.shared.enable()
                                    } else {
                                        try LoginItemManager.shared.disable()
                                    }
                                    loginItemError = nil
                                } catch {
                                    loginItemError = "Could not update login item: \(error.localizedDescription)"
                                    launchAtLogin = !newValue
                                    settings.launchAtLogin = !newValue
                                }
                            }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    if let error = loginItemError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(.horizontal, 4)
                    }
                }
                .padding(.horizontal, 32)

                // Slash commands per service
                VStack(alignment: .leading, spacing: 10) {
                    Text("Slash Commands")
                        .font(.headline)
                        .padding(.horizontal, 32)

                    if let dup = duplicateError {
                        Text(dup)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(.horizontal, 36)
                    }

                    ForEach(enabledServices) { service in
                        SlashCommandRow(
                            service: service,
                            commands: Binding(
                                get: { commandMap[service] ?? defaultCommands(for: service) },
                                set: { newVal in
                                    commandMap[service] = newVal
                                    validateAndSave()
                                }
                            )
                        )
                        .padding(.horizontal, 32)
                    }
                }
            }
            .padding(.vertical, 32)
        }
        .onAppear {
            launchAtLogin = settings.launchAtLogin
            // Load existing custom commands or defaults
            for service in enabledServices {
                commandMap[service] = settings.customSlashCommands[service.rawValue]
                    ?? defaultCommands(for: service)
            }
        }
    }

    private func defaultCommands(for service: ServiceType) -> [String] {
        SlashCommand.all.filter { $0.serviceType == service }.map { $0.command }
    }

    private func validateAndSave() {
        // Collect all commands across services
        var seen = Set<String>()
        var duplicates = Set<String>()
        for service in enabledServices {
            let cmds = commandMap[service] ?? defaultCommands(for: service)
            for cmd in cmds {
                let normalized = cmd.lowercased(with: Locale(identifier: "en"))
                if seen.contains(normalized) { duplicates.insert(cmd) }
                seen.insert(normalized)
            }
        }

        if !duplicates.isEmpty {
            duplicateError = "Duplicate commands: \(duplicates.joined(separator: ", "))"
        } else {
            duplicateError = nil
            // Save to settings
            for service in enabledServices {
                settings.customSlashCommands[service.rawValue] = commandMap[service]
            }
        }
    }
}

// MARK: - Slash command row

private struct SlashCommandRow: View {
    let service: ServiceType
    @Binding var commands: [String]
    @State private var editText: String = ""
    @State private var isEditing = false

    var body: some View {
        HStack(alignment: .top) {
            Image(service.iconName, bundle: nil)
                .resizable()
                .renderingMode(.template)
                .frame(width: 16, height: 16)
                .foregroundStyle(.secondary)
                .padding(.top, 2)

            Text(service.displayName)
                .font(.body)
                .frame(width: 90, alignment: .leading)

            if isEditing {
                TextField("e.g. /cl, /claude", text: $editText)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))
                    .onSubmit { commitEdit() }

                Button("Done") { commitEdit() }
                    .font(.caption)
            } else {
                Text(commands.joined(separator: ", "))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button("Edit") {
                    editText = commands.joined(separator: ", ")
                    isEditing = true
                }
                .font(.caption)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func commitEdit() {
        let parsed = editText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        if !parsed.isEmpty {
            commands = parsed
        }
        isEditing = false
    }
}
