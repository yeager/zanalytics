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
        audience: "https://api.zscaler.com",
        authMethod: .clientSecret
    )

    var isComplete: Bool {
        !clientID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !clientSecret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        URL(string: normalizedBaseURL) != nil
    }

    var normalizedBaseURL: String {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let cloud = cloudName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cloud.isEmpty && (trimmed.isEmpty || trimmed == "https://api.zsapi.net") {
            return cloud == "zscaler" ? "https://api.zsapi.net" : "https://api.\(cloud).zsapi.net"
        }
        return trimmed.hasSuffix("/") ? String(trimmed.dropLast()) : trimmed
    }

    var normalizedAudience: String {
        let trimmed = audience.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == "zscaler-oneapi" {
            return "https://api.zscaler.com"
        }
        return trimmed
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
