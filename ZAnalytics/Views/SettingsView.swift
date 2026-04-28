import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        TabView {
            OneAPISettingsView()
                .tabItem { Label("OneAPI", systemImage: "key") }
            EndpointTemplateSettingsView()
                .tabItem { Label(t("Endpoints", "Endpoints"), systemImage: "point.3.connected.trianglepath.dotted") }
            AppPreferencesView()
                .tabItem { Label("App", systemImage: "slider.horizontal.3") }
        }
        .padding(18)
    }

    private func t(_ english: String, _ swedish: String) -> String {
        L10n.text(english, swedish, language: appState.preferences.language)
    }
}

private struct OneAPISettingsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Form {
            Section {
                Text(t("Use Automation Hub (automate.zscaler.com) to create/verify your OneAPI client details. Client ID, secret, tenant, cloud, vanity domain, and base URL are saved in macOS Keychain.", "Använd Automation Hub (automate.zscaler.com) för att skapa/verifiera OneAPI-klientuppgifter. Klient-ID, hemlighet, tenant, moln, vanity-domän och bas-URL sparas i macOS Keychain."))
                    .foregroundStyle(.secondary)
            }

            Section(t("Authentication", "Autentisering")) {
                Picker(t("Method", "Metod"), selection: $appState.secureSettings.authMethod) {
                    ForEach(AuthMethod.allCases) { method in
                        Text(method.label).tag(method)
                    }
                }
                TextField(t("Client ID", "Klient-ID"), text: $appState.secureSettings.clientID)
                SecureField(t("Client secret or API secret", "Klienthemlighet eller API-hemlighet"), text: $appState.secureSettings.clientSecret)
                TextField("Audience", text: $appState.secureSettings.audience)
                    .help("Default from the Zscaler SDK: https://api.zscaler.com. Older saved value zscaler-oneapi is normalized automatically.")
            }

            Section("Tenant") {
                TextField(t("Base URL", "Bas-URL"), text: $appState.secureSettings.baseURL)
                TextField(t("Token path", "Token-sökväg"), text: $appState.secureSettings.tokenPath)
                TextField(t("Customer vanity domain", "Kundens vanity-domän"), text: $appState.secureSettings.vanityDomain)
                TextField(t("Cloud name", "Molnnamn"), text: $appState.secureSettings.cloudName)
                TextField(t("Tenant ID", "Tenant-ID"), text: $appState.secureSettings.tenantID)
            }

            Section {
                HStack {
                    Button {
                        appState.saveSecureSettings()
                    } label: {
                        Label(t("Save to Keychain", "Spara i Keychain"), systemImage: "lock")
                    }
                    Button {
                        Task { await appState.authenticateOneAPI() }
                    } label: {
                        if appState.isAuthenticating {
                            ProgressView().controlSize(.small)
                            Text(t("Authenticating", "Autentiserar"))
                        } else {
                            Label(t("Authenticate", "Autentisera"), systemImage: "key.viewfinder")
                        }
                    }
                    .disabled(appState.isAuthenticating || appState.isTestingConnection)
                    Button {
                        Task { await appState.testOneAPIConnection() }
                    } label: {
                        if appState.isTestingConnection {
                            ProgressView().controlSize(.small)
                            Text(t("Testing", "Testar"))
                        } else {
                            Label(t("Test Connection", "Testa anslutning"), systemImage: "network")
                        }
                    }
                    .disabled(appState.isAuthenticating || appState.isTestingConnection)
                    Button(role: .destructive) {
                        appState.clearSecureSettings()
                    } label: {
                        Label(t("Clear", "Rensa"), systemImage: "trash")
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
                Text(t("Authenticate only requests an OAuth token and decodes visible JWT metadata such as expiry and scopes when present. Test Connection also calls the currently selected report endpoint with a tiny limit so you can separate token issues from endpoint/RBAC issues.", "Autentisera hämtar bara en OAuth-token och avkodar synlig JWT-metadata som utgångstid och scope när de finns. Testa anslutning anropar även vald rapport-endpoint med en liten gräns så att tokenfel kan skiljas från endpoint-/RBAC-fel."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func t(_ english: String, _ swedish: String) -> String {
        L10n.text(english, swedish, language: appState.preferences.language)
    }
}

private struct EndpointTemplateSettingsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(t("Endpoint templates are editable because OneAPI analytics paths, REST vs GraphQL availability, fields, tenant features, license, rollout, and RBAC can vary. Confirm paths and query shapes in Automation Hub or tenant-specific docs.", "Endpoint-mallar är redigerbara eftersom OneAPI-analysvägar, REST kontra GraphQL, fält, tenant-funktioner, licens, utrullning och RBAC kan variera. Bekräfta sökvägar och query-format i Automation Hub eller tenant-specifik dokumentation."))
                .foregroundStyle(.secondary)
            List {
                ForEach($appState.endpointTemplates) { $template in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            TextField(t("Name", "Namn"), text: $template.displayName)
                                .font(.headline)
                            Picker("Transport", selection: $template.transport) {
                                ForEach(APITransport.allCases) { transport in
                                    Text(transport.rawValue).tag(transport)
                                }
                            }
                            .frame(width: 170)
                            if template.transport == .rest {
                                Picker(t("Method", "Metod"), selection: $template.method) {
                                    ForEach(HTTPMethod.allCases) { method in
                                        Text(method.rawValue).tag(method)
                                    }
                                }
                                .frame(width: 150)
                            }
                        }
                        HStack {
                            TextField(t("Key", "Nyckel"), text: $template.key)
                                .frame(width: 120)
                            TextField(t("Category", "Kategori"), text: $template.category)
                                .frame(width: 160)
                            if template.transport == .rest {
                                TextField(t("REST path template", "REST-sökvägsmall"), text: $template.pathTemplate)
                            } else {
                                TextField(t("GraphQL endpoint path", "GraphQL-endpoint-sökväg"), text: $template.graphqlEndpointPath)
                            }
                        }
                        if template.transport == .graphql {
                            VStack(alignment: .leading, spacing: 5) {
                                Text("GraphQL Query")
                                    .font(.caption.weight(.semibold))
                                TextField("query { ... }", text: $template.graphqlQuery, axis: .vertical)
                                    .font(.system(.caption, design: .monospaced))
                                    .lineLimit(5...12)
                                Text(t("Variables JSON", "Variabler JSON"))
                                    .font(.caption.weight(.semibold))
                                TextField("{ \"limit\": 100 }", text: $template.graphqlVariablesJSON, axis: .vertical)
                                    .font(.system(.caption, design: .monospaced))
                                    .lineLimit(2...8)
                                Text(t("The app sends POST { query, variables }. Built-in report variables are included automatically, and values in this JSON object override them.", "Appen skickar POST { query, variables }. Inbyggda rapportvariabler inkluderas automatiskt och värden i detta JSON-objekt skriver över dem."))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        TextField(t("Notes", "Anteckningar"), text: $template.notes, axis: .vertical)
                            .lineLimit(2...4)
                    }
                    .padding(.vertical, 6)
                }
            }
            HStack {
                Button {
                    appState.endpointTemplates.append(EndpointTemplate(key: "custom", displayName: "Custom Analytics", category: "Custom", pathTemplate: "/oneapi/analytics/custom/v1/report", graphqlQuery: EndpointTemplate.defaultGraphQLQuery(operationName: "customAnalytics"), notes: "Replace with your tenant-confirmed endpoint path or GraphQL query."))
                } label: {
                    Label(t("Add Template", "Lägg till mall"), systemImage: "plus")
                }
                Button {
                    appState.resetEndpointTemplates()
                } label: {
                    Label(t("Reset Defaults", "Återställ standard"), systemImage: "arrow.counterclockwise")
                }
                Spacer()
                Button {
                    appState.savePreferences()
                    appState.statusMessage = t("Endpoint templates saved.", "Endpoint-mallar sparade.")
                } label: {
                    Label(t("Save Templates", "Spara mallar"), systemImage: "square.and.arrow.down")
                }
            }
        }
    }

    private func t(_ english: String, _ swedish: String) -> String {
        L10n.text(english, swedish, language: appState.preferences.language)
    }
}

private struct AppPreferencesView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Form {
            Picker("Language / Språk", selection: Binding(
                get: { appState.preferences.language },
                set: {
                    appState.preferences.language = $0
                    appState.savePreferences()
                }
            )) {
                ForEach(AppLanguage.allCases) { language in
                    Text(language.label).tag(language)
                }
            }
            .pickerStyle(.segmented)

            Toggle(t("Use mock sample data", "Använd mockad exempeldata"), isOn: Binding(
                get: { appState.preferences.mockModeEnabled },
                set: {
                    appState.preferences.mockModeEnabled = $0
                    appState.savePreferences()
                }
            ))
            Toggle(t("Show onboarding at next launch", "Visa introduktion vid nästa start"), isOn: Binding(
                get: { !appState.preferences.hasCompletedOnboarding },
                set: {
                    appState.preferences.hasCompletedOnboarding = !$0
                    appState.savePreferences()
                }
            ))
            Text(t("Non-sensitive preferences are stored in UserDefaults. Secrets and tenant connection details stay in Keychain.", "Icke-känsliga inställningar sparas i UserDefaults. Hemligheter och tenant-anslutningsuppgifter stannar i Keychain."))
                .foregroundStyle(.secondary)
        }
    }

    private func t(_ english: String, _ swedish: String) -> String {
        L10n.text(english, swedish, language: appState.preferences.language)
    }
}
