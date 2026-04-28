import Foundation

struct AppPreferences: Codable, Equatable {
    var mockModeEnabled: Bool
    var hasCompletedOnboarding: Bool
    var exportFolderBookmark: Data?
    var language: AppLanguage

    static let defaults = AppPreferences(
        mockModeEnabled: true,
        hasCompletedOnboarding: false,
        exportFolderBookmark: nil,
        language: .english
    )

    init(
        mockModeEnabled: Bool,
        hasCompletedOnboarding: Bool,
        exportFolderBookmark: Data?,
        language: AppLanguage = .english
    ) {
        self.mockModeEnabled = mockModeEnabled
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.exportFolderBookmark = exportFolderBookmark
        self.language = language
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.mockModeEnabled = try container.decode(Bool.self, forKey: .mockModeEnabled)
        self.hasCompletedOnboarding = try container.decode(Bool.self, forKey: .hasCompletedOnboarding)
        self.exportFolderBookmark = try container.decodeIfPresent(Data.self, forKey: .exportFolderBookmark)
        self.language = try container.decodeIfPresent(AppLanguage.self, forKey: .language) ?? .english
    }
}

enum AppLanguage: String, Codable, CaseIterable, Identifiable {
    case english
    case swedish

    var id: String { rawValue }

    var label: String {
        switch self {
        case .english: return "🇬🇧 English"
        case .swedish: return "🇸🇪 Svenska"
        }
    }
}

enum L10n {
    static func text(_ english: String, _ swedish: String, language: AppLanguage) -> String {
        language == .swedish ? swedish : english
    }
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
