import Foundation
#if canImport(Security)
import Security
#endif

/// Session JWE, spike, and email. UserDefaults kept the same keys; first
/// read migrates them into the keychain and forgets the plaintext copy.
enum HelmKeychain {
  static let service = "com.gantree.helm"

  static func get(_ account: String) -> String? {
    #if canImport(Security)
    let q: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne,
    ]
    var out: AnyObject?
    let status = SecItemCopyMatching(q as CFDictionary, &out)
    guard status == errSecSuccess, let data = out as? Data else {
      return nil
    }
    return String(data: data, encoding: .utf8)
    #else
    return nil
    #endif
  }

  static func set(_ account: String, _ value: String?) {
    #if canImport(Security)
    let del: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
    ]
    SecItemDelete(del as CFDictionary)
    guard let value, !value.isEmpty, let data = value.data(using: .utf8) else {
      return
    }
    let add: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
      kSecValueData as String: data,
      kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
    ]
    SecItemAdd(add as CFDictionary, nil)
    #endif
  }
}
