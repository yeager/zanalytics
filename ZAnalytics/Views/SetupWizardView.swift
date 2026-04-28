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
                    Text("Set Up ZAnalytics")
                        .font(.title2.weight(.semibold))
                    Text("Use mock mode now, or connect OneAPI when your ZIdentity client is ready.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("Unofficial")
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
                        title: "What this app does",
                        systemImage: "chart.bar.doc.horizontal",
                        bodyText: "ZAnalytics helps build analytics report requests, run them against configurable OneAPI endpoint paths, and export clean JSON, CSV, or printable HTML reports. It is not affiliated with Zscaler."
                    )
                case 1:
                    WizardPage(
                        title: "OneAPI access",
                        systemImage: "person.badge.key",
                        bodyText: "Use Zscaler Automation Hub (https://automate.zscaler.com) as the primary OneAPI reference. Create API access in ZIdentity, assign only the RBAC permissions your reporting use case needs, and copy the client ID, client secret or API secret, tenant/cloud information, and base URL. Some analytics categories and cached/repeated-query behavior depend on your tenant and licenses."
                    )
                default:
                    VStack(alignment: .leading, spacing: 16) {
                        WizardPageHeader(title: "Choose a starting mode", systemImage: "switch.2")
                        Toggle("Explore with mock sample data", isOn: Binding(
                            get: { appState.preferences.mockModeEnabled },
                            set: {
                                appState.preferences.mockModeEnabled = $0
                                appState.savePreferences()
                            }
                        ))
                        .toggleStyle(.switch)
                        Text("Mock mode keeps credentials optional and makes every canned report runnable. Turn it off when your OneAPI settings validate.")
                            .foregroundStyle(.secondary)
                        Divider()
                        Button {
                            openSettings()
                        } label: {
                            Label("Open OneAPI Settings", systemImage: "key")
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
                Button("Back") { step = max(0, step - 1) }
                    .disabled(step == 0)
                Spacer()
                Button(step == 2 ? "Start Using ZAnalytics" : "Next") {
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
