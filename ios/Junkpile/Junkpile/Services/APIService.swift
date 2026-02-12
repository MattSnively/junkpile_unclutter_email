import Foundation

/// APIService handles all communication with the Junkpile backend server.
/// Uses Bearer token authentication for mobile requests.
final class APIService {

    // MARK: - Singleton

    /// Shared instance of the APIService
    static let shared = APIService()

    // MARK: - Configuration

    /// Base URL for the backend API
    /// TODO: Update this to your production server URL
    private let baseURL: String

    /// URL session for network requests
    private let session: URLSession

    /// Keychain service for token management
    private let keychain: KeychainService

    // MARK: - Initialization

    /// Private initializer to enforce singleton pattern
    private init() {
        // Base URL is determined by AppConfig:
        // - Debug builds → localhost for simulator testing
        // - Release builds → production HTTPS endpoint
        // - Can be overridden via API_BASE_URL environment variable
        self.baseURL = AppConfig.apiBaseURL

        // Configure URL session with reasonable timeouts
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)

        self.keychain = KeychainService.shared
    }

    // MARK: - Authentication Endpoints

    /// Exchanges an OAuth authorization code for access and refresh tokens.
    /// - Parameter code: The authorization code from Google OAuth
    /// - Returns: AuthTokenResponse with tokens on success
    func exchangeAuthCode(_ code: String) async throws -> AuthTokenResponse {
        let endpoint = "/api/auth/mobile"
        let body: [String: Any] = [
            "code": code,
            "platform": "ios"
        ]

        let response: AuthTokenResponse = try await post(endpoint, body: body, authenticated: false)

        // Store tokens if successful
        if response.success,
           let accessToken = response.accessToken,
           let expiresIn = response.expiresIn {
            keychain.storeAuthData(
                accessToken: accessToken,
                refreshToken: response.refreshToken,
                expiresIn: expiresIn,
                email: "", // Will be updated after token validation
                name: nil
            )
        }

        return response
    }

    /// Refreshes an expired access token using the refresh token.
    /// - Returns: RefreshTokenResponse with new access token
    func refreshAccessToken() async throws -> RefreshTokenResponse {
        guard let refreshToken = keychain.getRefreshToken() else {
            throw APIError.authenticationRequired
        }

        let endpoint = "/api/auth/refresh"
        let body: [String: Any] = [
            "refresh_token": refreshToken
        ]

        let response: RefreshTokenResponse = try await post(endpoint, body: body, authenticated: false)

        // Update stored access token if successful
        if response.success,
           let newAccessToken = response.accessToken,
           let expiresIn = response.expiresIn {
            keychain.setAccessToken(newAccessToken)
            let expiryDate = Date().addingTimeInterval(TimeInterval(expiresIn))
            keychain.setTokenExpiry(expiryDate)
        }

        return response
    }

    /// Validates the current access token and returns user info.
    /// - Returns: ValidateTokenResponse with validity and user email
    func validateToken() async throws -> ValidateTokenResponse {
        let endpoint = "/api/auth/validate"
        return try await get(endpoint, authenticated: true)
    }

    /// Gets the OAuth authorization URL from the server.
    /// - Returns: AuthUrlResponse with the Google OAuth URL
    func getAuthUrl() async throws -> AuthUrlResponse {
        let endpoint = "/api/auth/url"
        return try await get(endpoint, authenticated: false)
    }

    // MARK: - Apple Authentication Endpoints

    /// Exchanges an Apple identity token for a server session token.
    /// Called after the iOS app completes Sign in with Apple.
    ///
    /// - Parameters:
    ///   - identityToken: The JWT identity token from Apple Sign-In
    ///   - authorizationCode: The authorization code from Apple (optional)
    ///   - email: User's email (only provided on first sign-in)
    ///   - fullName: User's full name (only provided on first sign-in)
    /// - Returns: AppleAuthResponse with server session token on success
    func exchangeAppleToken(
        identityToken: String,
        authorizationCode: String?,
        email: String?,
        fullName: String?
    ) async throws -> AppleAuthResponse {
        let endpoint = "/api/auth/apple"
        var body: [String: Any] = [
            "identityToken": identityToken,
            "platform": "ios"
        ]
        if let authorizationCode = authorizationCode {
            body["authorizationCode"] = authorizationCode
        }
        if let email = email {
            body["email"] = email
        }
        if let fullName = fullName {
            body["fullName"] = fullName
        }

        return try await post(endpoint, body: body, authenticated: false)
    }

    /// Connects Gmail to an Apple Sign-In user account (two-step auth flow).
    /// Sends the Google auth code to the backend, which exchanges it for tokens
    /// and stores them on the user record.
    ///
    /// - Parameter code: The authorization code from Google OAuth
    /// - Returns: ConnectGmailResponse with Gmail tokens and email
    func connectGmail(_ code: String) async throws -> ConnectGmailResponse {
        let endpoint = "/api/auth/connect-gmail"
        let body: [String: Any] = [
            "code": code,
            "platform": "ios"
        ]

        // This endpoint requires the server session token (Apple user's bearer token)
        return try await post(endpoint, body: body, authenticated: true)
    }

    // MARK: - Email Endpoints

    /// Fetches emails with unsubscribe options from the user's Gmail.
    /// - Returns: Array of Email objects
    func fetchEmails() async throws -> [Email] {
        // Check token validity and refresh if needed
        try await ensureValidToken()

        let endpoint = "/api/emails"
        let response: EmailsResponse = try await get(endpoint, authenticated: true)

        guard response.success else {
            throw APIError.serverError(response.error ?? "Unknown error")
        }

        guard let emails = response.emails, !emails.isEmpty else {
            throw APIError.noEmailsFound
        }

        return emails
    }

    /// Records a decision (unsubscribe or keep) for an email.
    /// - Parameters:
    ///   - emailId: The Gmail message ID
    ///   - action: The action taken (unsubscribe or keep)
    /// - Returns: DecisionAPIResponse indicating success
    func recordDecision(emailId: String, action: DecisionAction) async throws -> DecisionAPIResponse {
        // Check token validity and refresh if needed
        try await ensureValidToken()

        let endpoint = "/api/decision"
        let body: [String: Any] = [
            "emailId": emailId,
            "decision": action.rawValue
        ]

        return try await post(endpoint, body: body, authenticated: true)
    }

    // MARK: - Statistics Endpoints

    /// Fetches aggregated statistics from the server.
    /// - Returns: StatsResponse with statistics data
    func fetchStats() async throws -> StatsResponse {
        try await ensureValidToken()

        let endpoint = "/api/stats"
        return try await get(endpoint, authenticated: true)
    }

    // MARK: - Account Management

    /// Requests permanent account deletion from the server.
    /// Clears all server-side data and revokes OAuth tokens.
    /// The caller is responsible for clearing local data afterward.
    /// - Returns: APIResponse indicating success
    func deleteAccount() async throws -> APIResponse {
        try await ensureValidToken()

        let endpoint = "/api/account"
        return try await delete(endpoint, authenticated: true)
    }

    // MARK: - Session Management

    /// Logs the user out, clearing server session.
    func logout() async throws {
        let endpoint = "/api/logout"
        let _: APIResponse = try await post(endpoint, body: [:], authenticated: true)
        keychain.clearAllAuthData()
    }

    // MARK: - Token Management

    /// Ensures a valid token is available, refreshing if needed.
    /// For Google users: checks the Google access token and refreshes if expired.
    /// For Apple users: checks the server session token exists (it has 7-day expiry
    /// handled server-side). Gmail token refresh happens via the backend.
    private func ensureValidToken() async throws {
        // Check if we have any credentials at all
        guard keychain.hasStoredCredentials() else {
            throw APIError.authenticationRequired
        }

        // For Apple users with a server session token, the token validity
        // is managed server-side. We only need to refresh Gmail tokens.
        if keychain.getAuthProvider() == .apple {
            // Apple users: server session token is valid for 7 days.
            // Gmail token refresh is handled by the backend middleware.
            guard keychain.getServerSessionToken() != nil else {
                throw APIError.authenticationRequired
            }
            return
        }

        // For Google users: check if the Google access token is expired
        if keychain.isTokenExpired() {
            let refreshResponse = try await refreshAccessToken()
            if !refreshResponse.success {
                throw APIError.tokenExpired
            }
        }
    }

    /// Resolves the Bearer token to use for authenticated requests.
    /// Apple users use their server session token; Google users use their Google access token.
    /// - Returns: The appropriate Bearer token string
    /// - Throws: APIError.authenticationRequired if no token is available
    private func resolveAuthToken() throws -> String {
        // For Apple users, prefer the server session token
        if keychain.getAuthProvider() == .apple,
           let sessionToken = keychain.getServerSessionToken() {
            return sessionToken
        }

        // For Google users (or fallback), use the Google access token
        if let accessToken = keychain.getAccessToken() {
            return accessToken
        }

        throw APIError.authenticationRequired
    }

    // MARK: - HTTP Methods

    /// Performs a GET request to the specified endpoint.
    /// - Parameters:
    ///   - endpoint: The API endpoint (e.g., "/api/emails")
    ///   - authenticated: Whether to include the Bearer token
    /// - Returns: Decoded response of type T
    private func get<T: Decodable>(_ endpoint: String, authenticated: Bool) async throws -> T {
        guard let url = URL(string: baseURL + endpoint) else {
            throw APIError.networkError("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        // Add authorization header — uses server session token (Apple) or access token (Google)
        if authenticated {
            let token = try resolveAuthToken()
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        return try await executeRequest(request)
    }

    /// Performs a POST request to the specified endpoint.
    /// - Parameters:
    ///   - endpoint: The API endpoint
    ///   - body: The request body as a dictionary
    ///   - authenticated: Whether to include the Bearer token
    /// - Returns: Decoded response of type T
    private func post<T: Decodable>(_ endpoint: String, body: [String: Any], authenticated: Bool) async throws -> T {
        guard let url = URL(string: baseURL + endpoint) else {
            throw APIError.networkError("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        // Encode request body
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        // Add authorization header — uses server session token (Apple) or access token (Google)
        if authenticated {
            let token = try resolveAuthToken()
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        return try await executeRequest(request)
    }

    /// Performs a DELETE request to the specified endpoint.
    /// - Parameters:
    ///   - endpoint: The API endpoint (e.g., "/api/account")
    ///   - authenticated: Whether to include the Bearer token
    /// - Returns: Decoded response of type T
    private func delete<T: Decodable>(_ endpoint: String, authenticated: Bool) async throws -> T {
        guard let url = URL(string: baseURL + endpoint) else {
            throw APIError.networkError("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        // Add authorization header — uses server session token (Apple) or access token (Google)
        if authenticated {
            let token = try resolveAuthToken()
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        return try await executeRequest(request)
    }

    /// Executes a URL request and decodes the response.
    /// - Parameter request: The URLRequest to execute
    /// - Returns: Decoded response of type T
    private func executeRequest<T: Decodable>(_ request: URLRequest) async throws -> T {
        do {
            let (data, response) = try await session.data(for: request)

            // Check HTTP status code
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            // Handle HTTP errors
            switch httpResponse.statusCode {
            case 200...299:
                break // Success
            case 401:
                throw APIError.authenticationRequired
            case 403:
                throw APIError.tokenExpired
            default:
                // Try to decode error message from response
                if let errorResponse = try? JSONDecoder().decode(APIResponse.self, from: data) {
                    throw APIError.serverError(errorResponse.error ?? "HTTP \(httpResponse.statusCode)")
                }
                throw APIError.serverError("HTTP \(httpResponse.statusCode)")
            }

            // Decode the response
            let decoder = JSONDecoder()
            return try decoder.decode(T.self, from: data)

        } catch let error as APIError {
            throw error
        } catch let error as DecodingError {
            print("Decoding error: \(error)")
            throw APIError.invalidResponse
        } catch {
            throw APIError.networkError(error.localizedDescription)
        }
    }
}
