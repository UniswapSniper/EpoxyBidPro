import Foundation
import Security

// ═══════════════════════════════════════════════════════════════════════════════
// KeychainService.swift
// Secure token storage using iOS Keychain instead of UserDefaults.
// ═══════════════════════════════════════════════════════════════════════════════

enum KeychainKey: String {
    case accessToken  = "ebp_access_token"
    case refreshToken = "ebp_refresh_token"
    case userId       = "ebp_user_id"
}

enum KeychainService {

    private static let service = "com.epoxybidpro.app"

    // MARK: - Save

    @discardableResult
    static func save(key: KeychainKey, data: Data) -> Bool {
        // Delete existing first to avoid duplicates
        delete(key: key)

        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecValueData as String:   data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    @discardableResult
    static func save(key: KeychainKey, string: String) -> Bool {
        guard let data = string.data(using: .utf8) else { return false }
        return save(key: key, data: data)
    }

    // MARK: - Load

    static func load(key: KeychainKey) -> Data? {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    static func loadString(key: KeychainKey) -> String? {
        guard let data = load(key: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - Delete

    @discardableResult
    static func delete(key: KeychainKey) -> Bool {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    // MARK: - Clear All

    static func clearAll() {
        KeychainKey.allCases.forEach { delete(key: $0) }
    }
}

// MARK: - CaseIterable conformance for clearAll

extension KeychainKey: CaseIterable {}
