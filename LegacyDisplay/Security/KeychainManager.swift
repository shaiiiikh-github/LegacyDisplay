import Foundation
import Security

/// Secure password storage using the iOS Keychain (Section 10, Rule 5).
/// Never logs passwords or sensitive data.
public final class KeychainManager {

    public static let shared = KeychainManager()
    private let serviceName = "com.legacydisplay.vnc"

    private init() {}

    public func savePassword(_ password: String, forHost host: String, port: Int) -> Bool {
        let account = "\(host):\(port)"
        guard let data = password.data(using: .utf8) else { return false }

        // Delete existing item first
        deletePassword(forHost: host, port: port)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    public func getPassword(forHost host: String, port: Int) -> String? {
        let account = "\(host):\(port)"
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    public func deletePassword(forHost host: String, port: Int) -> Bool {
        let account = "\(host):\(port)"
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
