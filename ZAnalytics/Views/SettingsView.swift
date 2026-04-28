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
                Text("Use Automation Hub (automate.zscaler.com) to create/verify your OneAPI client details. Client ID, secret, tenant, cloud, vanity domain, and base URL are saved in macOS Keychain.")
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
                    Button {
                        Task { await appState.authenticateOneAPI() }
                    } label: {
                        if appState.isAuthenticating {
                            ProgressView().controlSize(.small)
                            Text("Authenticating")
                        } else {
                            Label("Authenticate", systemImage: "key.viewfinder")
                        }
                    }
                    .disabled(appState.isAuthenticating || appState.isTestingConnection)
                    Button {
                        Task { await appState.testOneAPIConnection() }
                    } label: {
                        if appState.isTestingConnection {
                            ProgressView().controlSize(.small)
                            Text("Testing")
                        } else {
                            Label("Test Connection", systemImage: "network")
                        }
                    }
                    .disabled(appState.isAuthenticating || appState.isTestingConnection)
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
                if let authStatus = appState.authStatusMessage {
                    Label(authStatus, systemImage: "checkmark.seal")
                        .font(.caption)
                        .foregroundStyle(.green)
                        .textSelection(.enabled)
                }
                if let connectionStatus = appState.connectionStatusMessage {
                    Label(connectionStatus, systemImage: "checkmark.icloud")
                        .font(.caption)
                        .foregroundStyle(.green)
                        .textSelection(.enabled)
                }
                Text("Authenticate only requests an OAuth token and decodes visible JWT metadata such as expiry and scopes when present. Test Connection also calls the currently selected report endpoint with a tiny limit so you can separate token issues from endpoint/RBAC issues.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct EndpointTemplateSettingsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Endpoint templates are editable because OneAPI analytics paths, REST vs GraphQL availability, fields, tenant features, license, rollout, and RBAC can vary. Confirm paths and query shapes in Automation Hub or tenant-specific docs.")
                .foregroundStyle(.secondary)
            List {
                ForEach($appState.endpointTemplates) { $template in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            TextField("Name", text: $template.displayName)
                                .font(.headline)
                            Picker("Transport", selection: $template.transport) {
                                ForEach(APITransport.allCases) { transport in
                                    Text(transport.rawValue).tag(transport)
                                }
                            }
                            .frame(width: 170)
                            if template.transport == .rest {
                                Picker("Method", selection: $template.method) {
                                    ForEach(HTTPMethod.allCases) { method in
                                        Text(method.rawValue).tag(method)
                                    }
                                }
                                .frame(width: 150)
                            }
                        }
                        HStack {
                            TextField("Key", text: $template.key)
                                .frame(width: 120)
                            TextField("Category", text: $template.category)
                                .frame(width: 160)
                            if template.transport == .rest {
                                TextField("REST path template", text: $template.pathTemplate)
                            } else {
                                TextField("GraphQL endpoint path", text: $template.graphqlEndpointPath)
                            }
                        }
                        if template.transport == .graphql {
                            VStack(alignment: .leading, spacing: 5) {
                                Text("GraphQL Query")
                                    .font(.caption.weight(.semibold))
                                TextField("query { ... }", text: $template.graphqlQuery, axis: .vertical)
                                    .font(.system(.caption, design: .monospaced))
                                    .lineLimit(5...12)
                                Text("Variables JSON")
                                    .font(.caption.weight(.semibold))
                                TextField("{ \"limit\": 100 }", text: $template.graphqlVariablesJSON, axis: .vertical)
                                    .font(.system(.caption, design: .monospaced))
                                    .lineLimit(2...8)
                                Text("The app sends POST { query, variables }. Built-in report variables are included automatically, and values in this JSON object override them.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        TextField("Notes", text: $template.notes, axis: .vertical)
                            .lineLimit(2...4)
                    }
                    .padding(.vertical, 6)
                }
            }
            HStack {
                Button {
                    appState.endpointTemplates.append(EndpointTemplate(key: "custom", displayName: "Custom Analytics", category: "Custom", pathTemplate: "/oneapi/analytics/custom/v1/report", graphqlQuery: EndpointTemplate.defaultGraphQLQuery(operationName: "customAnalytics"), notes: "Replace with your tenant-confirmed endpoint path or GraphQL query."))
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
