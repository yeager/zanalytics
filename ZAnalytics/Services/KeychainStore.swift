import Foundation
import Security

protocol SecureSettingsStoring {
    func load() throws -> OneAPISettings
    func save(_ settings: OneAPISettings) throws
    func delete() throws
}

final class SecureSettingsStore: SecureSettingsStoring {
    private let service = "com.zanalytics.oneapi"
    private let account = "settings"

    func load() throws -> OneAPISettings {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound {
            return .empty
        }
        guard status == errSecSuccess else {
            throw KeychainError.unhandled(status)
        }
        guard let data = item as? Data else {
            throw KeychainError.invalidData
        }
        return try JSONDecoder().decode(OneAPISettings.self, from: data)
    }

    func save(_ settings: OneAPISettings) throws {
        let data = try JSONEncoder().encode(settings)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        var query = baseQuery()
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            query[kSecValueData as String] = data
            query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let addStatus = SecItemAdd(query as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainError.unhandled(addStatus)
            }
        } else if status != errSecSuccess {
            throw KeychainError.unhandled(status)
        }
    }

    func delete() throws {
        let status = SecItemDelete(baseQuery() as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandled(status)
        }
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}

enum KeychainError: LocalizedError {
    case invalidData
    case unhandled(OSStatus)

    var errorDescription: String? {
        switch self {
        case .invalidData:
            return "The Keychain item could not be decoded."
        case .unhandled(let status):
            return SecCopyErrorMessageString(status, nil) as String? ?? "Keychain error \(status)."
        }
    }
}
