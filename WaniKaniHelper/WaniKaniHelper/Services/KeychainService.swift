// Thin wrapper around the Security framework for storing and retrieving the WaniKani API key.
// Uses kSecClassGenericPassword so the key is encrypted by the OS and survives app reinstalls.
import Foundation
import Security

enum KeychainService {
    private static let service = "com.fuyu.wanikanihelper"
    // The WaniKani API key. Additional credentials (e.g. the Anthropic key) use their own account.
    private static let defaultAccount = "apiKey"

    static func save(_ key: String, account: String = defaultAccount) {
        let data = Data(key.utf8)
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecValueData:   data
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    static func load(account: String = defaultAccount) -> String? {
        let query: [CFString: Any] = [
            kSecClass:            kSecClassGenericPassword,
            kSecAttrService:      service,
            kSecAttrAccount:      account,
            kSecReturnData:       true,
            kSecMatchLimit:       kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(account: String = defaultAccount) {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
