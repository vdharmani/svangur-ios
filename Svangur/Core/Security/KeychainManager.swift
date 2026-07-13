import Foundation

protocol KeychainManagerProtocol: Sendable {
    func save(_ data: Data, key: String) throws(AppError)
    func read(key: String) -> Data?
    func delete(key: String) throws(AppError)
}

final class KeychainManager: KeychainManagerProtocol, Sendable {
    private let service: String

    init(service: String = Bundle.main.bundleIdentifier ?? "co.Svangur") {
        self.service = service
    }

    func save(_ data: Data, key: String) throws(AppError) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecValueData as String: data
        ]
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw .unknown(message: "Keychain save failed (\(status))")
        }
    }

    func read(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    func delete(key: String) throws(AppError) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw .unknown(message: "Keychain delete failed (\(status))")
        }
    }
}

extension KeychainManagerProtocol {
    func saveCodable<T: Encodable>(_ value: T, key: String) throws(AppError) {
        do {
            let data = try JSONEncoder().encode(value)
            try save(data, key: key)
        } catch let error as AppError {
            throw error
        } catch {
            throw .unknown(message: "Encode failed: \(error.localizedDescription)")
        }
    }

    func readCodable<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = read(key: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
