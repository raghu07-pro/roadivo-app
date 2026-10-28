import Foundation
import Security

/// Small secrets (playlist links with embedded credentials). A protocol so
/// tests and UI tests use memory instead of the real Keychain.
protocol SecureStore: Sendable {
    func set(_ value: String, for key: String) throws
    func string(for key: String) throws -> String?
    func remove(_ key: String) throws
    /// Deletes every secret the app stored. iOS keeps Keychain items after the app is deleted.
    func removeAll() throws
}

struct KeychainError: Error, Equatable {
    let status: OSStatus
}

struct KeychainStore: SecureStore {
    var service = "com.playcartv.secure"

    func set(_ value: String, for key: String) throws {
        let data = Data(value.utf8)
        let query = baseQuery(key)
        let update: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        if status == errSecItemNotFound {
            var insert = query
            insert[kSecValueData as String] = data
            insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let added = SecItemAdd(insert as CFDictionary, nil)
            guard added == errSecSuccess else { throw KeychainError(status: added) }
        } else if status != errSecSuccess {
            throw KeychainError(status: status)
        }
    }

    func string(for key: String) throws -> String? {
        var query = baseQuery(key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess, let data = result as? Data else { throw KeychainError(status: status) }
        return String(data: data, encoding: .utf8)
    }

    func remove(_ key: String) throws {
        let status = SecItemDelete(baseQuery(key) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw KeychainError(status: status) }
    }

    func removeAll() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw KeychainError(status: status) }
    }

    private func baseQuery(_ key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
    }
}

/// Memory-only `SecureStore` for tests, previews and UI-test launches.
final class InMemorySecureStore: SecureStore, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: String] = [:]

    func set(_ value: String, for key: String) throws {
        lock.withLock { values[key] = value }
    }

    func string(for key: String) throws -> String? {
        lock.withLock { values[key] }
    }

    func remove(_ key: String) throws {
        _ = lock.withLock { values.removeValue(forKey: key) }
    }

    func removeAll() throws {
        lock.withLock { values.removeAll() }
    }
}
