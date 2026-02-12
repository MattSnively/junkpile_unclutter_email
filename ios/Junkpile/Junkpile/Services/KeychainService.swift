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

    /// Keys for different stored values.
    /// Original keys (accessToken through userName) store Google/Gmail OAuth data.
    /// Apple-specific keys track the identity provider and Apple user state.
    private enum Key: String {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case tokenExpiry = "token_expiry"
        case userEmail = "user_email"
        case userName = "user_name"
        case authProvider = "auth_provider"              // "apple" or "google"
        case appleUserIdentifier = "apple_user_id"       // Apple's stable user ID (sub claim)
        case serverSessionToken = "server_session_token"  // Server-issued JWT for Apple users
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

    // MARK: - Auth Provider Storage

    /// Stores which authentication provider was used for sign-in.
    /// - Parameter provider: The auth provider (apple or google)
    /// - Returns: True if storage was successful
    @discardableResult
    func setAuthProvider(_ provider: AuthProvider) -> Bool {
        return set(provider.rawValue, forKey: Key.authProvider.rawValue)
    }

    /// Retrieves the stored authentication provider.
    /// - Returns: The auth provider if stored, nil otherwise
    func getAuthProvider() -> AuthProvider? {
        guard let rawValue = get(forKey: Key.authProvider.rawValue) else {
            return nil
        }
        return AuthProvider(rawValue: rawValue)
    }

    // MARK: - Apple Sign-In Storage

    /// Stores the Apple user identifier (the `sub` claim from Apple's identity token).
    /// This is a stable identifier that persists across sign-in sessions.
    /// - Parameter identifier: Apple's user identifier string
    /// - Returns: True if storage was successful
    @discardableResult
    func setAppleUserIdentifier(_ identifier: String) -> Bool {
        return set(identifier, forKey: Key.appleUserIdentifier.rawValue)
    }

    /// Retrieves the stored Apple user identifier.
    /// - Returns: The Apple user identifier if stored, nil otherwise
    func getAppleUserIdentifier() -> String? {
        return get(forKey: Key.appleUserIdentifier.rawValue)
    }

    /// Stores the server-issued session token (JWT) for Apple Sign-In users.
    /// This token is used as the Bearer token for API requests instead of a Google access token.
    /// - Parameter token: The server session token
    /// - Returns: True if storage was successful
    @discardableResult
    func setServerSessionToken(_ token: String) -> Bool {
        return set(token, forKey: Key.serverSessionToken.rawValue)
    }

    /// Retrieves the stored server session token.
    /// - Returns: The server session token if stored, nil otherwise
    func getServerSessionToken() -> String? {
        return get(forKey: Key.serverSessionToken.rawValue)
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
    /// Removes both Google OAuth tokens and Apple Sign-In data.
    func clearAllAuthData() {
        // Google/Gmail tokens
        delete(forKey: Key.accessToken.rawValue)
        delete(forKey: Key.refreshToken.rawValue)
        delete(forKey: Key.tokenExpiry.rawValue)
        // User identity info
        delete(forKey: Key.userEmail.rawValue)
        delete(forKey: Key.userName.rawValue)
        // Provider tracking
        delete(forKey: Key.authProvider.rawValue)
        // Apple-specific
        delete(forKey: Key.appleUserIdentifier.rawValue)
        delete(forKey: Key.serverSessionToken.rawValue)
    }

    /// Checks if any user credentials are stored (either Google or Apple).
    /// For Google users: checks for a Google access token.
    /// For Apple users: checks for a server session token (they may not have Gmail connected yet).
    /// - Returns: True if either Google access token or Apple session token exists
    func hasStoredCredentials() -> Bool {
        return getAccessToken() != nil || getServerSessionToken() != nil
    }

    /// Checks specifically for Gmail OAuth credentials (Google access token).
    /// Apple Sign-In users may be authenticated but not have Gmail connected.
    /// - Returns: True if a Google/Gmail access token exists
    func hasGmailCredentials() -> Bool {
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
