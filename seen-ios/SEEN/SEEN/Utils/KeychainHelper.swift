//
//  KeychainHelper.swift
//  SEEN
//
//  Secure storage for tokens using Keychain
//

import Foundation
import Security

enum KeychainHelper {
    
    enum KeychainError: Error {
        case duplicateEntry
        case unknown(OSStatus)
        case notFound
        case encodingError
    }
    
    private static let service = "com.obey.SEEN"
    
    static func save(_ data: Data, forKey key: String) throws {
        // Delete any existing item first
        try? delete(forKey: key)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw KeychainError.unknown(status)
        }
    }
    
    static func save(_ string: String, forKey key: String) throws {
        guard let data = string.data(using: .utf8) else {
            throw KeychainError.encodingError
        }
        try save(data, forKey: key)
    }
    
    static func read(forKey key: String) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess, let data = result as? Data else {
            if status == errSecItemNotFound {
                throw KeychainError.notFound
            }
            throw KeychainError.unknown(status)
        }
        
        return data
    }
    
    static func readString(forKey key: String) throws -> String {
        let data = try read(forKey: key)
        guard let string = String(data: data, encoding: .utf8) else {
            throw KeychainError.encodingError
        }
        return string
    }
    
    static func delete(forKey key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unknown(status)
        }
    }
    
    static func deleteAll() {
        try? delete(forKey: "accessToken")
        try? delete(forKey: "refreshToken")
    }
}
