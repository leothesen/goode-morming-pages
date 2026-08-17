import Foundation
import Security

/// The Notion integration token, stored in the login keychain.
///
/// Never `UserDefaults`: that is a plist in your home directory readable by any
/// process running as you, and this token can write to your journal.
enum Keychain {
    private static let service = "co.leothesen.GoodeMormingPages"
    private static let account = "notionIntegrationToken"

    static var notionToken: String? {
        get { read(account: account) }
        set {
            if let newValue, !newValue.isEmpty {
                write(newValue, account: account)
            } else {
                delete(account: account)
            }
        }
    }

    private static func read(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let string = String(data: data, encoding: .utf8),
              !string.isEmpty
        else { return nil }
        return string
    }

    private static func write(_ value: String, account: String) {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let data = Data(value.utf8)

        // Update in place if it exists, otherwise add. SecItemAdd on an existing
        // item returns errSecDuplicateItem rather than overwriting.
        let status = SecItemUpdate(
            base as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )
        if status == errSecItemNotFound {
            var insert = base
            insert[kSecValueData as String] = data
            insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            SecItemAdd(insert as CFDictionary, nil)
        }
    }

    private static func delete(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
