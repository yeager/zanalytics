import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var secureSettings: OneAPISettings = .empty
    @Published var preferences: AppPreferences
    @Published var endpointTemplates: [EndpointTemplate]
    @Published var selectedReport: ReportDefinition
    @Published var reportRequest: ReportRequest
    @Published var latestResult: ReportResult?
    @Published var isLoading = false
    @Published var statusMessage: String?
    @Published var errorMessage: String?

    let reportCatalog = ReportCatalog.defaults
    private let settingsStore: SecureSettingsStoring
    private let preferenceStore: PreferenceStoring
    private let exportService = ReportExportService()

    init(
        settingsStore: SecureSettingsStoring = SecureSettingsStore(),
        preferenceStore: PreferenceStoring = UserDefaultsPreferenceStore()
    ) {
        self.settingsStore = settingsStore
        self.preferenceStore = preferenceStore
        self.preferences = preferenceStore.loadPreferences()
        self.endpointTemplates = preferenceStore.loadEndpointTemplates()
        self.selectedReport = ReportCatalog.defaults[0]
        self.reportRequest = ReportRequest(definition: ReportCatalog.defaults[0])
        self.secureSettings = (try? settingsStore.load()) ?? .empty
    }

    var setupState: SetupState {
        if preferences.mockModeEnabled {
            return .mockMode
        }
        return secureSettings.isComplete ? .ready : .needsSetup
    }

    func saveSecureSettings() {
        do {
            try settingsStore.save(secureSettings)
            errorMessage = nil
            statusMessage = "Secure OneAPI settings saved in macOS Keychain."
        } catch {
            errorMessage = "Could not save settings to Keychain: \(error.localizedDescription)"
        }
    }

    func clearSecureSettings() {
        do {
            try settingsStore.delete()
            secureSettings = .empty
            statusMessage = "Secure settings removed from Keychain."
        } catch {
            errorMessage = "Could not remove secure settings: \(error.localizedDescription)"
        }
    }

    func savePreferences() {
        preferenceStore.savePreferences(preferences)
        preferenceStore.saveEndpointTemplates(endpointTemplates)
    }

    func resetEndpointTemplates() {
        endpointTemplates = EndpointTemplate.defaults
        preferenceStore.saveEndpointTemplates(endpointTemplates)
        statusMessage = "Endpoint templates reset to placeholder defaults."
    }

    func selectReport(_ report: ReportDefinition) {
        selectedReport = report
        reportRequest = ReportRequest(definition: report)
        latestResult = nil
        errorMessage = nil
        statusMessage = nil
    }

    func runSelectedReport() async {
        isLoading = true
        errorMessage = nil
        statusMessage = nil
        defer { isLoading = false }

        do {
            if preferences.mockModeEnabled {
                latestResult = MockDataProvider.result(for: reportRequest, definition: selectedReport)
            } else {
                try validateLiveSettings()
                let client = OneAPIClient(settings: secureSettings)
                latestResult = try await client.runReport(reportRequest, using: endpointTemplates)
            }
            statusMessage = "Report generated at \(DateFormatter.shortDateTime.string(from: Date()))."
        } catch {
            errorMessage = ReportErrorPresenter.message(for: error)
        }
    }

    func exportLatestResult(as format: ExportFormat) -> URL? {
        guard let latestResult else {
            errorMessage = "Run a report before exporting."
            return nil
        }

        do {
            let url = try exportService.export(latestResult, as: format)
            statusMessage = "Exported \(format.label) to \(url.path)."
            return url
        } catch {
            errorMessage = "Export failed: \(error.localizedDescription)"
            return nil
        }
    }

    private func validateLiveSettings() throws {
        var issues: [String] = []
        if secureSettings.clientID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append("Client ID is required.")
        }
        if secureSettings.clientSecret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append("Client secret or API secret is required.")
        }
        if secureSettings.baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append("Base URL is required.")
        }
        if !issues.isEmpty {
            throw ValidationError(issues: issues)
        }
    }
}

enum SetupState {
    case mockMode
    case needsSetup
    case ready
}

struct ValidationError: LocalizedError {
    let issues: [String]
    var errorDescription: String? { issues.joined(separator: "\n") }
}

enum ReportErrorPresenter {
    static func message(for error: Error) -> String {
        if let validation = error as? ValidationError {
            return validation.issues.joined(separator: "\n")
        }
        if let api = error as? OneAPIError {
            return api.localizedDescription
        }
        return error.localizedDescription
    }
}

extension DateFormatter {
    static let shortDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}
