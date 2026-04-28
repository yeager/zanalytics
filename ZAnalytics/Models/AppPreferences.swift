import Foundation

struct AppPreferences: Codable, Equatable {
    var mockModeEnabled: Bool
    var hasCompletedOnboarding: Bool
    var exportFolderBookmark: Data?

    static let defaults = AppPreferences(
        mockModeEnabled: true,
        hasCompletedOnboarding: false,
        exportFolderBookmark: nil
    )
}

protocol PreferenceStoring {
    func loadPreferences() -> AppPreferences
    func savePreferences(_ preferences: AppPreferences)
    func loadEndpointTemplates() -> [EndpointTemplate]
    func saveEndpointTemplates(_ templates: [EndpointTemplate])
}

final class UserDefaultsPreferenceStore: PreferenceStoring {
    private let defaults: UserDefaults
    private let preferencesKey = "app.preferences.v1"
    private let endpointsKey = "endpoint.templates.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadPreferences() -> AppPreferences {
        guard let data = defaults.data(forKey: preferencesKey),
              let preferences = try? JSONDecoder().decode(AppPreferences.self, from: data) else {
            return .defaults
        }
        return preferences
    }

    func savePreferences(_ preferences: AppPreferences) {
        if let data = try? JSONEncoder().encode(preferences) {
            defaults.set(data, forKey: preferencesKey)
        }
    }

    func loadEndpointTemplates() -> [EndpointTemplate] {
        guard let data = defaults.data(forKey: endpointsKey),
              let templates = try? JSONDecoder().decode([EndpointTemplate].self, from: data),
              !templates.isEmpty else {
            return EndpointTemplate.defaults
        }
        return templates
    }

    func saveEndpointTemplates(_ templates: [EndpointTemplate]) {
        if let data = try? JSONEncoder().encode(templates) {
            defaults.set(data, forKey: endpointsKey)
        }
    }
}
