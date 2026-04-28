import SwiftUI

struct SetupWizardView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openSettings) private var openSettings
    @State private var step = 0

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text(t("Set Up ZAnalytics", "Konfigurera ZAnalytics"))
                        .font(.title2.weight(.semibold))
                    Text(t("Use mock mode now, or connect OneAPI when your ZIdentity client is ready.", "Använd mockläge nu, eller anslut OneAPI när din ZIdentity-klient är klar."))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(t("Unofficial", "Inofficiell"))
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.orange.opacity(0.16), in: Capsule())
            }
            .padding(24)

            Divider()

            Group {
                switch step {
                case 0:
                    WizardPage(
                        title: t("What this app does", "Vad appen gör"),
                        systemImage: "chart.bar.doc.horizontal",
                        bodyText: t("ZAnalytics helps build analytics report requests, run them against configurable OneAPI endpoint paths, and export clean JSON, CSV, or printable HTML reports. It is not affiliated with Zscaler.", "ZAnalytics hjälper till att bygga analysrapportbegäranden, köra dem mot konfigurerbara OneAPI-endpoint-sökvägar och exportera rena JSON-, CSV- eller utskrivbara HTML-rapporter. Appen är inte kopplad till Zscaler.")
                    )
                case 1:
                    WizardPage(
                        title: "OneAPI access",
                        systemImage: "person.badge.key",
                        bodyText: t("Use Zscaler Automation Hub (https://automate.zscaler.com) as the primary OneAPI reference. Create API access in ZIdentity, assign only the RBAC permissions your reporting use case needs, and copy the client ID, client secret or API secret, tenant/cloud information, and base URL. Some analytics categories and cached/repeated-query behavior depend on your tenant and licenses.", "Använd Zscaler Automation Hub (https://automate.zscaler.com) som primär OneAPI-referens. Skapa API-åtkomst i ZIdentity, tilldela bara de RBAC-behörigheter rapportbehovet kräver och kopiera klient-ID, klienthemlighet eller API-hemlighet, tenant-/molninformation och bas-URL. Vissa analyskategorier och cache-/upprepade-frågor-beteenden beror på tenant och licenser.")
                    )
                default:
                    VStack(alignment: .leading, spacing: 16) {
                        WizardPageHeader(title: t("Choose a starting mode", "Välj startläge"), systemImage: "switch.2")
                        Toggle(t("Explore with mock sample data", "Utforska med mockad exempeldata"), isOn: Binding(
                            get: { appState.preferences.mockModeEnabled },
                            set: {
                                appState.preferences.mockModeEnabled = $0
                                appState.savePreferences()
                            }
                        ))
                        .toggleStyle(.switch)
                        Text(t("Mock mode keeps credentials optional and makes every canned report runnable. Turn it off when your OneAPI settings validate.", "Mockläge gör autentiseringsuppgifter valfria och gör alla färdiga rapporter körbara. Stäng av det när OneAPI-inställningarna validerar."))
                            .foregroundStyle(.secondary)
                        Divider()
                        Button {
                            openSettings()
                        } label: {
                            Label(t("Open OneAPI Settings", "Öppna OneAPI-inställningar"), systemImage: "key")
                        }
                    }
                    .padding(28)
                }
            }
            .overlay(alignment: .bottom) {
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(index == step ? Color.accentColor : Color.secondary.opacity(0.35))
                            .frame(width: 7, height: 7)
                    }
                }
                .padding(.bottom, 12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()
            HStack {
                Button(t("Back", "Tillbaka")) { step = max(0, step - 1) }
                    .disabled(step == 0)
                Spacer()
                Button(step == 2 ? t("Start Using ZAnalytics", "Börja använda ZAnalytics") : t("Next", "Nästa")) {
                    if step == 2 {
                        appState.preferences.hasCompletedOnboarding = true
                        appState.savePreferences()
                        dismiss()
                    } else {
                        step += 1
                    }
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(20)
        }
    }

    private func t(_ english: String, _ swedish: String) -> String {
        L10n.text(english, swedish, language: appState.preferences.language)
    }
}

private struct WizardPage: View {
    let title: String
    let systemImage: String
    let bodyText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            WizardPageHeader(title: title, systemImage: systemImage)
            Text(bodyText)
                .font(.body)
                .lineSpacing(3)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(28)
    }
}

private struct WizardPageHeader: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 30))
                .frame(width: 44, height: 44)
                .foregroundStyle(.blue)
            Text(title)
                .font(.title.weight(.semibold))
        }
    }
}
