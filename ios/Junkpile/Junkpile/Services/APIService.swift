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
        // Configure base URL from environment or use default
        // In production, this should point to your server
        self.baseURL = ProcessInfo.processInfo.environment["API_BASE_URL"]
            ?? "http://localhost:3000"

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

    // MARK: - Session Management

    /// Logs the user out, clearing server session.
    func logout() async throws {
        let endpoint = "/api/logout"
        let _: APIResponse = try await post(endpoint, body: [:], authenticated: true)
        keychain.clearAllAuthData()
    }

    // MARK: - Token Management

    /// Ensures a valid token is available, refreshing if needed.
    private func ensureValidToken() async throws {
        // Check if we have a token at all
        guard keychain.hasStoredCredentials() else {
            throw APIError.authenticationRequired
        }

        // Check if token is expired
        if keychain.isTokenExpired() {
            // Try to refresh the token
            let refreshResponse = try await refreshAccessToken()
            if !refreshResponse.success {
                throw APIError.tokenExpired
            }
        }
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

        // Add authorization header if authenticated
        if authenticated {
            guard let token = keychain.getAccessToken() else {
                throw APIError.authenticationRequired
            }
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

        // Add authorization header if authenticated
        if authenticated {
            guard let token = keychain.getAccessToken() else {
                throw APIError.authenticationRequired
            }
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
