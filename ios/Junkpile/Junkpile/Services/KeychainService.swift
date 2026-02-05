import Foundation
import Security

/// KeychainService provides secure storage for sensitive data like OAuth tokens.
/// Uses iOS Keychain to store credentials securely, never in UserDefaults or plain files.
final class KeychainService {

    // MARK: - Singleton

    /// Shared instance of the KeychainService
    static let shared = KeychainService()

    // MARK: - Constants

    /// Service identifier for Keychain items (bundle ID based)
    private let serviceIdentifier = "com.junkpile.app"

    /// Keys for different stored values
    private enum Key: String {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case tokenExpiry = "token_expiry"
        case userEmail = "user_email"
        case userName = "user_name"
    }

    // MARK: - Initialization

    /// Private initializer to enforce singleton pattern
    private init() {}

    // MARK: - Token Storage

    /// Stores the OAuth access token securely.
    /// - Parameter token: The access token to store
    /// - Returns: True if storage was successful
    @discardableResult
    func setAccessToken(_ token: String) -> Bool {
        return set(token, forKey: Key.accessToken.rawValue)
    }

    /// Retrieves the stored OAuth access token.
    /// - Returns: The access token if stored, nil otherwise
    func getAccessToken() -> String? {
        return get(forKey: Key.accessToken.rawValue)
    }

    /// Stores the OAuth refresh token securely.
    /// - Parameter token: The refresh token to store
    /// - Returns: True if storage was successful
    @discardableResult
    func setRefreshToken(_ token: String) -> Bool {
        return set(token, forKey: Key.refreshToken.rawValue)
    }

    /// Retrieves the stored OAuth refresh token.
    /// - Returns: The refresh token if stored, nil otherwise
    func getRefreshToken() -> String? {
        return get(forKey: Key.refreshToken.rawValue)
    }

    /// Stores the token expiry timestamp.
    /// - Parameter date: The expiry date
    /// - Returns: True if storage was successful
    @discardableResult
    func setTokenExpiry(_ date: Date) -> Bool {
        let timestamp = String(date.timeIntervalSince1970)
        return set(timestamp, forKey: Key.tokenExpiry.rawValue)
    }

    /// Retrieves the stored token expiry date.
    /// - Returns: The expiry date if stored, nil otherwise
    func getTokenExpiry() -> Date? {
        guard let timestampString = get(forKey: Key.tokenExpiry.rawValue),
              let timestamp = Double(timestampString) else {
            return nil
        }
        return Date(timeIntervalSince1970: timestamp)
    }

    /// Checks if the stored access token is expired.
    /// - Returns: True if expired or no expiry date stored, false otherwise
    func isTokenExpired() -> Bool {
        guard let expiry = getTokenExpiry() else {
            return true // No expiry stored, consider expired
        }
        // Add a 5-minute buffer before actual expiry
        return expiry.addingTimeInterval(-300) < Date()
    }

    // MARK: - User Info Storage

    /// Stores the user's email address.
    /// - Parameter email: The user's email
    /// - Returns: True if storage was successful
    @discardableResult
    func setUserEmail(_ email: String) -> Bool {
        return set(email, forKey: Key.userEmail.rawValue)
    }

    /// Retrieves the stored user email.
    /// - Returns: The email if stored, nil otherwise
    func getUserEmail() -> String? {
        return get(forKey: Key.userEmail.rawValue)
    }

    /// Stores the user's display name.
    /// - Parameter name: The user's display name
    /// - Returns: True if storage was successful
    @discardableResult
    func setUserName(_ name: String) -> Bool {
        return set(name, forKey: Key.userName.rawValue)
    }

    /// Retrieves the stored user name.
    /// - Returns: The name if stored, nil otherwise
    func getUserName() -> String? {
        return get(forKey: Key.userName.rawValue)
    }

    // MARK: - Bulk Operations

    /// Stores all authentication tokens and user info at once.
    /// - Parameters:
    ///   - accessToken: The OAuth access token
    ///   - refreshToken: The OAuth refresh token (optional)
    ///   - expiresIn: Seconds until the access token expires
    ///   - email: User's email address
    ///   - name: User's display name (optional)
    func storeAuthData(
        accessToken: String,
        refreshToken: String?,
        expiresIn: Int,
        email: String,
        name: String?
    ) {
        setAccessToken(accessToken)
        if let refreshToken = refreshToken {
            setRefreshToken(refreshToken)
        }
        let expiryDate = Date().addingTimeInterval(TimeInterval(expiresIn))
        setTokenExpiry(expiryDate)
        setUserEmail(email)
        if let name = name {
            setUserName(name)
        }
    }

    /// Clears all stored authentication data (for logout).
    func clearAllAuthData() {
        delete(forKey: Key.accessToken.rawValue)
        delete(forKey: Key.refreshToken.rawValue)
        delete(forKey: Key.tokenExpiry.rawValue)
        delete(forKey: Key.userEmail.rawValue)
        delete(forKey: Key.userName.rawValue)
    }

    /// Checks if user credentials are stored.
    /// - Returns: True if access token exists
    func hasStoredCredentials() -> Bool {
        return getAccessToken() != nil
    }

    // MARK: - Private Keychain Methods

    /// Stores a string value in the Keychain.
    /// - Parameters:
    ///   - value: The string value to store
    ///   - key: The key to store it under
    /// - Returns: True if successful
    private func set(_ value: String, forKey key: String) -> Bool {
        // First, try to delete any existing item
        delete(forKey: key)

        // Convert string to data
        guard let data = value.data(using: .utf8) else {
            return false
        }

        // Build the query dictionary for adding the item
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        // Add the item to the Keychain
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    /// Retrieves a string value from the Keychain.
    /// - Parameter key: The key to retrieve
    /// - Returns: The stored string value, or nil if not found
    private func get(forKey key: String) -> String? {
        // Build the query dictionary for retrieving the item
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        // Try to retrieve the item
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        // Check if retrieval was successful
        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }

        return value
    }

    /// Deletes a value from the Keychain.
    /// - Parameter key: The key to delete
    @discardableResult
    private func delete(forKey key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
