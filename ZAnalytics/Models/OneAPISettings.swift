import Foundation

struct OneAPISettings: Codable, Equatable {
    var clientID: String
    var clientSecret: String
    var baseURL: String
    var tokenPath: String
    var vanityDomain: String
    var cloudName: String
    var tenantID: String
    var audience: String
    var authMethod: AuthMethod

    static let empty = OneAPISettings(
        clientID: "",
        clientSecret: "",
        baseURL: "https://api.zsapi.net",
        tokenPath: "/oauth2/v1/token",
        vanityDomain: "",
        cloudName: "",
        tenantID: "",
        audience: "zscaler-oneapi",
        authMethod: .clientSecret
    )

    var isComplete: Bool {
        !clientID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !clientSecret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        URL(string: normalizedBaseURL) != nil
    }

    var normalizedBaseURL: String {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasSuffix("/") ? String(trimmed.dropLast()) : trimmed
    }
}

enum AuthMethod: String, Codable, CaseIterable, Identifiable {
    case clientSecret
    case signedJWT

    var id: String { rawValue }

    var label: String {
        switch self {
        case .clientSecret: return "Client Secret"
        case .signedJWT: return "Signed JWT Ready"
        }
    }
}
