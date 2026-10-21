import Foundation
import Security

public enum ProviderCredential: Sendable {
    case apiKey(String), chatGPT
    var apiKey: String {
        get throws {
            guard case .apiKey(let key) = self, !key.isEmpty else {
                throw BrainstormError.invalid("This provider requires an API key. Subscription credentials cannot be used for API billing.")
            }
            return key
        }
    }
}

public protocol CredentialStore: Sendable {
    func credential(for provider: ProviderID) async throws -> ProviderCredential
}

public struct WorkspaceCredentials: CredentialStore {
    let keychain: KeychainCredentials
    let subscription: CodexSubscription
    public init(keychain: KeychainCredentials, subscription: CodexSubscription) {
        self.keychain = keychain; self.subscription = subscription
    }
    public func credential(for provider: ProviderID) async throws -> ProviderCredential {
        if provider == .chatGPT {
            try await subscription.requireSubscription()
            return .chatGPT
        }
        return .apiKey(try await keychain.key(for: provider))
    }
}

public actor KeychainCredentials {
    private let service = "app.brainstorm.native.api-keys"
    public init() {}
    public func key(for provider: ProviderID) throws -> String {
        var query = baseQuery(provider)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { throw BrainstormError.missingKey(provider) }
        guard status == errSecSuccess, let data = result as? Data, let key = String(data: data, encoding: .utf8), !key.isEmpty else {
            throw error(status)
        }
        return key
    }
    public func hasKey(for provider: ProviderID) throws -> Bool {
        do { _ = try key(for: provider); return true }
        catch BrainstormError.missingKey { return false }
    }
    public func save(_ key: String, for provider: ProviderID) throws {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains(where: \.isWhitespace) else {
            throw BrainstormError.invalid("Enter a valid API key without spaces.")
        }
        let query = baseQuery(provider)
        let values = [kSecValueData as String: Data(trimmed.utf8)] as [String: Any]
        let status = SecItemUpdate(query as CFDictionary, values as CFDictionary)
        if status == errSecItemNotFound {
            var item = query.merging(values) { _, new in new }
            item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            let added = SecItemAdd(item as CFDictionary, nil)
            guard added == errSecSuccess else { throw error(added) }
        } else if status != errSecSuccess { throw error(status) }
    }
    public func remove(for provider: ProviderID) throws {
        let status = SecItemDelete(baseQuery(provider) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw error(status) }
    }
    private func baseQuery(_ provider: ProviderID) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: provider.rawValue]
    }
    private func error(_ status: OSStatus) -> BrainstormError {
        .storage("Keychain: \(SecCopyErrorMessageString(status, nil) as String? ?? String(status))")
    }
}
