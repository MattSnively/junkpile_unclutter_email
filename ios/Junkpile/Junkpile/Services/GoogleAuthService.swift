import Foundation
import AuthenticationServices

/// GoogleAuthService handles Google OAuth authentication using ASWebAuthenticationSession.
/// This provides a secure in-app browser for authentication without requiring external Safari.
@MainActor
final class GoogleAuthService: NSObject, ObservableObject {

    // MARK: - Singleton

    /// Shared instance of the GoogleAuthService
    static let shared = GoogleAuthService()

    // MARK: - Published State

    /// Whether authentication is currently in progress
    @Published var isAuthenticating = false

    /// Error message from the last authentication attempt
    @Published var errorMessage: String?

    // MARK: - Configuration

    /// Google OAuth client ID (configured in Google Cloud Console)
    /// TODO: Replace with your actual client ID
    private let clientId = "YOUR_GOOGLE_CLIENT_ID.apps.googleusercontent.com"

    /// Redirect URI scheme (must match URL Types in Info.plist)
    private let redirectScheme = "com.junkpile.app"

    /// Redirect URI (full URL)
    private var redirectUri: String {
        return "\(redirectScheme):/oauth2callback"
    }

    /// Scopes required for Gmail access
    private let scopes = [
        "https://www.googleapis.com/auth/gmail.readonly",
        "https://www.googleapis.com/auth/gmail.modify",
        "email",
        "profile"
    ]

    // MARK: - Private Properties

    /// Current authentication session
    private var authSession: ASWebAuthenticationSession?

    /// API service for token exchange
    private let apiService = APIService.shared

    /// Keychain service for token storage
    private let keychain = KeychainService.shared

    // MARK: - Initialization

    /// Private initializer to enforce singleton pattern
    private override init() {
        super.init()
    }

    // MARK: - Authentication

    /// Initiates the Google OAuth flow.
    /// - Parameter presentationAnchor: The window to present the auth sheet from
    /// - Returns: True if authentication was successful
    func signIn(presentationAnchor: ASPresentationAnchor) async throws -> Bool {
        // Prevent concurrent authentication attempts
        guard !isAuthenticating else {
            throw GoogleAuthError.authenticationInProgress
        }

        isAuthenticating = true
        errorMessage = nil

        defer {
            isAuthenticating = false
        }

        do {
            // Step 1: Get the authorization code via ASWebAuthenticationSession
            let authCode = try await performOAuthFlow(presentationAnchor: presentationAnchor)

            // Step 2: Exchange the code for tokens via our backend
            let tokenResponse = try await apiService.exchangeAuthCode(authCode)

            guard tokenResponse.success else {
                let error = tokenResponse.error ?? "Unknown error during token exchange"
                errorMessage = error
                throw GoogleAuthError.tokenExchangeFailed(error)
            }

            // Step 3: Validate the token and get user info
            let validateResponse = try await apiService.validateToken()

            if let email = validateResponse.email {
                keychain.setUserEmail(email)
            }

            return true

        } catch let error as GoogleAuthError {
            errorMessage = error.localizedDescription
            throw error
        } catch {
            errorMessage = error.localizedDescription
            throw GoogleAuthError.networkError(error.localizedDescription)
        }
    }

    /// Performs the OAuth flow using ASWebAuthenticationSession.
    /// - Parameter presentationAnchor: The window to present the auth sheet from
    /// - Returns: The authorization code from Google
    private func performOAuthFlow(presentationAnchor: ASPresentationAnchor) async throws -> String {
        // Build the Google OAuth URL
        let authUrl = buildAuthorizationUrl()

        return try await withCheckedThrowingContinuation { continuation in
            // Create the authentication session
            let session = ASWebAuthenticationSession(
                url: authUrl,
                callbackURLScheme: redirectScheme
            ) { callbackUrl, error in
                // Handle cancellation
                if let error = error as? ASWebAuthenticationSessionError,
                   error.code == .canceledLogin {
                    continuation.resume(throwing: GoogleAuthError.userCancelled)
                    return
                }

                // Handle other errors
                if let error = error {
                    continuation.resume(throwing: GoogleAuthError.sessionError(error.localizedDescription))
                    return
                }

                // Extract the authorization code from the callback URL
                guard let callbackUrl = callbackUrl,
                      let code = self.extractAuthorizationCode(from: callbackUrl) else {
                    continuation.resume(throwing: GoogleAuthError.invalidCallback)
                    return
                }

                continuation.resume(returning: code)
            }

            // Configure the session
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false // Allow cookies for "Remember Me"

            // Store reference and start the session
            self.authSession = session

            if !session.start() {
                continuation.resume(throwing: GoogleAuthError.sessionStartFailed)
            }
        }
    }

    /// Builds the Google OAuth authorization URL with all required parameters.
    /// - Returns: The complete authorization URL
    private func buildAuthorizationUrl() -> URL {
        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!

        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectUri),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scopes.joined(separator: " ")),
            URLQueryItem(name: "access_type", value: "offline"), // Request refresh token
            URLQueryItem(name: "prompt", value: "consent"), // Force consent screen for refresh token
            URLQueryItem(name: "include_granted_scopes", value: "true")
        ]

        return components.url!
    }

    /// Extracts the authorization code from the OAuth callback URL.
    /// - Parameter url: The callback URL from Google
    /// - Returns: The authorization code, or nil if not found
    private func extractAuthorizationCode(from url: URL) -> String? {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)

        // Check for error parameter
        if let errorParam = components?.queryItems?.first(where: { $0.name == "error" })?.value {
            print("OAuth error: \(errorParam)")
            return nil
        }

        // Extract the code parameter
        return components?.queryItems?.first(where: { $0.name == "code" })?.value
    }

    // MARK: - Sign Out

    /// Signs the user out, clearing all stored credentials.
    func signOut() async {
        // Clear local credentials first
        keychain.clearAllAuthData()

        // Optionally notify the backend
        do {
            try await apiService.logout()
        } catch {
            // Log but don't fail - local sign out is what matters
            print("Backend logout failed: \(error)")
        }
    }

    // MARK: - Token Refresh

    /// Refreshes the access token using the stored refresh token.
    /// - Returns: True if refresh was successful
    func refreshTokenIfNeeded() async throws -> Bool {
        // Check if we need to refresh
        guard keychain.isTokenExpired() else {
            return true // Token is still valid
        }

        // Attempt to refresh
        let response = try await apiService.refreshAccessToken()

        return response.success
    }

    // MARK: - State Check

    /// Checks if the user has valid stored credentials.
    /// - Returns: True if credentials exist (doesn't validate them)
    func hasStoredCredentials() -> Bool {
        return keychain.hasStoredCredentials()
    }

    /// Validates the stored credentials with the server.
    /// - Returns: True if credentials are valid
    func validateStoredCredentials() async throws -> Bool {
        guard hasStoredCredentials() else {
            return false
        }

        // Try to refresh if expired
        if keychain.isTokenExpired() {
            let refreshed = try await refreshTokenIfNeeded()
            if !refreshed {
                return false
            }
        }

        // Validate with server
        let response = try await apiService.validateToken()
        return response.valid
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension GoogleAuthService: ASWebAuthenticationPresentationContextProviding {

    /// Provides the presentation anchor for the authentication session.
    /// - Parameter session: The authentication session
    /// - Returns: The window to present the auth sheet from
    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // Return the first active window scene's key window
        return ASPresentationAnchor()
    }
}

// MARK: - Error Types

/// Errors that can occur during Google authentication
enum GoogleAuthError: Error, LocalizedError {
    case authenticationInProgress
    case userCancelled
    case sessionStartFailed
    case sessionError(String)
    case invalidCallback
    case tokenExchangeFailed(String)
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .authenticationInProgress:
            return "Authentication is already in progress"
        case .userCancelled:
            return "Sign in was cancelled"
        case .sessionStartFailed:
            return "Failed to start authentication session"
        case .sessionError(let message):
            return "Authentication error: \(message)"
        case .invalidCallback:
            return "Invalid response from Google"
        case .tokenExchangeFailed(let message):
            return "Failed to complete sign in: \(message)"
        case .networkError(let message):
            return "Network error: \(message)"
        }
    }
}
