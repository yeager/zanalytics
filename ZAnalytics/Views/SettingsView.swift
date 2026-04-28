import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        TabView {
            OneAPISettingsView()
                .tabItem { Label("OneAPI", systemImage: "key") }
            EndpointTemplateSettingsView()
                .tabItem { Label("Endpoints", systemImage: "point.3.connected.trianglepath.dotted") }
            AppPreferencesView()
                .tabItem { Label("App", systemImage: "slider.horizontal.3") }
        }
        .padding(18)
    }
}

private struct OneAPISettingsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Form {
            Section {
                Text("Store your ZIdentity-created OneAPI client details here. Client ID, secret, tenant, cloud, vanity domain, and base URL are saved in macOS Keychain.")
                    .foregroundStyle(.secondary)
            }

            Section("Authentication") {
                Picker("Method", selection: $appState.secureSettings.authMethod) {
                    ForEach(AuthMethod.allCases) { method in
                        Text(method.label).tag(method)
                    }
                }
                TextField("Client ID", text: $appState.secureSettings.clientID)
                SecureField("Client secret or API secret", text: $appState.secureSettings.clientSecret)
                TextField("Audience", text: $appState.secureSettings.audience)
            }

            Section("Tenant") {
                TextField("Base URL", text: $appState.secureSettings.baseURL)
                TextField("Token path", text: $appState.secureSettings.tokenPath)
                TextField("Customer vanity domain", text: $appState.secureSettings.vanityDomain)
                TextField("Cloud name", text: $appState.secureSettings.cloudName)
                TextField("Tenant ID", text: $appState.secureSettings.tenantID)
            }

            Section {
                HStack {
                    Button {
                        appState.saveSecureSettings()
                    } label: {
                        Label("Save to Keychain", systemImage: "lock")
                    }
                    Button(role: .destructive) {
                        appState.clearSecureSettings()
                    } label: {
                        Label("Clear", systemImage: "trash")
                    }
                    Spacer()
                }
                if let status = appState.statusMessage {
                    Text(status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct EndpointTemplateSettingsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Endpoint templates are editable because OneAPI analytics paths and fields may differ by tenant, license, feature rollout, and RBAC. Placeholders are intentionally visible.")
                .foregroundStyle(.secondary)
            List {
                ForEach($appState.endpointTemplates) { $template in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            TextField("Name", text: $template.displayName)
                                .font(.headline)
                            Picker("Method", selection: $template.method) {
                                ForEach(HTTPMethod.allCases) { method in
                                    Text(method.rawValue).tag(method)
                                }
                            }
                            .frame(width: 150)
                        }
                        HStack {
                            TextField("Key", text: $template.key)
                                .frame(width: 120)
                            TextField("Category", text: $template.category)
                                .frame(width: 160)
                            TextField("Path template", text: $template.pathTemplate)
                        }
                        TextField("Notes", text: $template.notes, axis: .vertical)
                            .lineLimit(2...4)
                    }
                    .padding(.vertical, 6)
                }
            }
            HStack {
                Button {
                    appState.endpointTemplates.append(EndpointTemplate(key: "custom", displayName: "Custom Analytics", category: "Custom", pathTemplate: "/oneapi/analytics/custom/v1/report", notes: "Replace with your tenant-confirmed endpoint path."))
                } label: {
                    Label("Add Template", systemImage: "plus")
                }
                Button {
                    appState.resetEndpointTemplates()
                } label: {
                    Label("Reset Defaults", systemImage: "arrow.counterclockwise")
                }
                Spacer()
                Button {
                    appState.savePreferences()
                    appState.statusMessage = "Endpoint templates saved."
                } label: {
                    Label("Save Templates", systemImage: "square.and.arrow.down")
                }
            }
        }
    }
}

private struct AppPreferencesView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Form {
            Toggle("Use mock sample data", isOn: Binding(
                get: { appState.preferences.mockModeEnabled },
                set: {
                    appState.preferences.mockModeEnabled = $0
                    appState.savePreferences()
                }
            ))
            Toggle("Show onboarding at next launch", isOn: Binding(
                get: { !appState.preferences.hasCompletedOnboarding },
                set: {
                    appState.preferences.hasCompletedOnboarding = !$0
                    appState.savePreferences()
                }
            ))
            Text("Non-sensitive preferences are stored in UserDefaults. Secrets and tenant connection details stay in Keychain.")
                .foregroundStyle(.secondary)
        }
    }
}
