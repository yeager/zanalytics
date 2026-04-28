import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationSplitView {
            SidebarView()
        } detail: {
            VStack(spacing: 0) {
                HeaderView()
                Divider()
                HSplitView {
                    ReportBuilderView()
                        .frame(minWidth: 420, idealWidth: 470)
                    ReportResultView()
                        .frame(minWidth: 540)
                }
            }
        }
        .sheet(isPresented: onboardingBinding) {
            SetupWizardView()
                .environmentObject(appState)
                .frame(width: 780, height: 620)
        }
        .alert("ZAnalytics", isPresented: Binding(
            get: { appState.errorMessage != nil },
            set: { if !$0 { appState.errorMessage = nil } }
        )) {
            Button("OK") { appState.errorMessage = nil }
        } message: {
            Text(appState.errorMessage ?? "")
        }
    }

    private var onboardingBinding: Binding<Bool> {
        Binding(
            get: { !appState.preferences.hasCompletedOnboarding },
            set: { newValue in
                appState.preferences.hasCompletedOnboarding = !newValue
                appState.savePreferences()
            }
        )
    }
}

private struct SidebarView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        List(appState.reportCatalog, selection: Binding(
            get: { appState.selectedReport.id },
            set: { id in
                if let report = appState.reportCatalog.first(where: { $0.id == id }) {
                    appState.selectReport(report)
                }
            }
        )) { report in
            VStack(alignment: .leading, spacing: 5) {
                Text(report.name)
                    .font(.headline)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Text(report.category)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .padding(.vertical, 5)
            .tag(report.id)
        }
        .navigationTitle("Reports")
        .navigationSplitViewColumnWidth(min: 260, ideal: 300, max: 380)
        .safeAreaInset(edge: .bottom) {
            VStack(alignment: .leading, spacing: 8) {
                Divider()
                Label(statusLabel, systemImage: statusIcon)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Unofficial helper. Not affiliated with Zscaler.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
        }
    }

    private var statusLabel: String {
        switch appState.setupState {
        case .mockMode: return "Mock data mode enabled"
        case .needsSetup: return "OneAPI setup needed"
        case .ready: return "OneAPI settings ready"
        }
    }

    private var statusIcon: String {
        switch appState.setupState {
        case .mockMode: return "wand.and.stars"
        case .needsSetup: return "exclamationmark.triangle"
        case .ready: return "checkmark.seal"
        }
    }
}

private struct HeaderView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("ZAnalytics")
                    .font(.system(size: 26, weight: .semibold))
                Text("Unofficial Zscaler OneAPI analytics helper. Tenant endpoints, features, and RBAC vary.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("Mock Data", isOn: Binding(
                get: { appState.preferences.mockModeEnabled },
                set: {
                    appState.preferences.mockModeEnabled = $0
                    appState.savePreferences()
                }
            ))
            .toggleStyle(.switch)
            Button {
                openSettings()
            } label: {
                Label("Settings", systemImage: "gearshape")
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.background)
    }
}
