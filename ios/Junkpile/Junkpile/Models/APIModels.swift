import Foundation

// MARK: - Email Models

/// Email represents an email fetched from the Gmail API.
/// Contains all information needed to display an email card and process unsubscribe actions.
struct Email: Codable, Identifiable, Equatable {
    /// Gmail message ID (used as unique identifier)
    let id: String

    /// Sender name (cleaned of quotes and brackets)
    let sender: String

    /// Email subject line
    let subject: String

    /// Full HTML body of the email (for preview rendering)
    let htmlBody: String?

    /// Extracted unsubscribe URL (from List-Unsubscribe header or email body)
    let unsubscribeUrl: String?

    /// Raw email headers for additional parsing if needed
    let rawHeaders: EmailHeaders?

    /// Computed preview text (first 150 characters of subject or a default message)
    var preview: String {
        if subject.isEmpty {
            return "(No Subject)"
        }
        return subject
    }

    /// Check if email has a valid unsubscribe option
    var hasUnsubscribeOption: Bool {
        return unsubscribeUrl != nil && !unsubscribeUrl!.isEmpty
    }
}

/// Raw email headers returned from the API
struct EmailHeaders: Codable, Equatable {
    let from: String?
    let listUnsubscribe: String?

    enum CodingKeys: String, CodingKey {
        case from
        case listUnsubscribe = "listUnsubscribe"
    }
}

// MARK: - Authentication Models

/// Response from the /api/auth/url endpoint
struct AuthUrlResponse: Codable {
    let authUrl: String?
    let error: String?
}

/// Response from the /api/auth/mobile endpoint (mobile OAuth token exchange)
struct AuthTokenResponse: Codable {
    let success: Bool
    let accessToken: String?
    let refreshToken: String?
    let expiresIn: Int?
    let tokenType: String?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case success
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
        case error
    }
}

/// Response from the /api/auth/refresh endpoint
struct RefreshTokenResponse: Codable {
    let success: Bool
    let accessToken: String?
    let expiresIn: Int?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case success
        case accessToken = "access_token"
        case expiresIn = "expires_in"
        case error
    }
}

/// Response from the /api/auth/validate endpoint
struct ValidateTokenResponse: Codable {
    let valid: Bool
    let email: String?
    let expiresAt: String?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case valid
        case email
        case expiresAt = "expires_at"
        case error
    }
}

// MARK: - Email API Models

/// Response from the /api/emails endpoint
struct EmailsResponse: Codable {
    let success: Bool
    let emails: [Email]?
    let error: String?
    let message: String?
}

/// Request body for the /api/decision endpoint
struct DecisionAPIRequest: Codable {
    let emailId: String
    let decision: String
}

/// Response from the /api/decision endpoint
struct DecisionAPIResponse: Codable {
    let success: Bool
    let message: String?
    let error: String?
}

// MARK: - Statistics Models

/// Response from the /api/stats endpoint
struct StatsResponse: Codable {
    let success: Bool
    let stats: StatsData?
    let error: String?
}

/// Statistics data from the backend
struct StatsData: Codable {
    let totalSessions: Int
    let completedSessions: Int
    let totalDecisions: Int
    let totalUnsubscribes: Int

    enum CodingKeys: String, CodingKey {
        case totalSessions
        case completedSessions
        case totalDecisions
        case totalUnsubscribes
    }

    /// Calculated total keeps
    var totalKeeps: Int {
        return totalDecisions - totalUnsubscribes
    }

    /// Unsubscribe rate as percentage
    var unsubscribeRate: Double {
        guard totalDecisions > 0 else { return 0 }
        return (Double(totalUnsubscribes) / Double(totalDecisions)) * 100
    }
}

// MARK: - Generic API Response

/// Generic API response wrapper for simple success/error responses
struct APIResponse: Codable {
    let success: Bool
    let message: String?
    let error: String?
}

// MARK: - Error Types

/// Custom error types for API operations
enum APIError: Error, LocalizedError {
    case networkError(String)
    case authenticationRequired
    case tokenExpired
    case invalidResponse
    case serverError(String)
    case noEmailsFound
    case gmailNotConfigured

    var errorDescription: String? {
        switch self {
        case .networkError(let message):
            return "Network error: \(message)"
        case .authenticationRequired:
            return "Please sign in to continue"
        case .tokenExpired:
            return "Your session has expired. Please sign in again."
        case .invalidResponse:
            return "Invalid response from server"
        case .serverError(let message):
            return "Server error: \(message)"
        case .noEmailsFound:
            return "No emails with unsubscribe options found"
        case .gmailNotConfigured:
            return "Gmail integration is not configured"
        }
    }
}

// MARK: - User-Facing Error

/// Maps raw API errors to friendly, actionable messages for the UI.
/// Each error type gets a human-readable title, guidance message,
/// SF Symbol icon, and a context-appropriate action label.
struct UserFacingError: Equatable {
    /// Short headline displayed prominently (e.g. "No Connection")
    let title: String

    /// Guidance text explaining what happened and what the user can do
    let message: String

    /// SF Symbol name for the error illustration
    let iconName: String

    /// Label for the primary action button (e.g. "Try Again", "Sign In")
    let actionLabel: String

    /// Converts a typed APIError into a user-friendly error representation.
    /// Each case maps to a specific title/message/icon/action combo.
    static func from(_ error: APIError) -> UserFacingError {
        switch error {
        case .networkError:
            return UserFacingError(
                title: "No Connection",
                message: "Check your Wi-Fi or cellular connection and try again.",
                iconName: "wifi.slash",
                actionLabel: "Try Again"
            )
        case .authenticationRequired:
            return UserFacingError(
                title: "Sign-In Required",
                message: "Please sign in to access your emails.",
                iconName: "person.crop.circle.badge.exclamationmark",
                actionLabel: "Sign In"
            )
        case .tokenExpired:
            return UserFacingError(
                title: "Session Expired",
                message: "Your session has expired. Please sign in again.",
                iconName: "clock.badge.exclamationmark",
                actionLabel: "Sign In"
            )
        case .invalidResponse:
            return UserFacingError(
                title: "Something Went Wrong",
                message: "We got an unexpected response. Please try again.",
                iconName: "exclamationmark.bubble",
                actionLabel: "Try Again"
            )
        case .serverError:
            return UserFacingError(
                title: "Server Trouble",
                message: "Our servers are having a moment. Please try again shortly.",
                iconName: "server.rack",
                actionLabel: "Try Again"
            )
        case .noEmailsFound:
            return UserFacingError(
                title: "Inbox Already Clean",
                message: "No emails with unsubscribe options found. Nice work!",
                iconName: "sparkles",
                actionLabel: "Go Home"
            )
        case .gmailNotConfigured:
            return UserFacingError(
                title: "Gmail Not Connected",
                message: "Gmail integration needs to be set up before you can start.",
                iconName: "envelope.badge.shield.half.filled",
                actionLabel: "Go to Settings"
            )
        }
    }

    /// Fallback error for unexpected/untyped errors
    static func generic() -> UserFacingError {
        return UserFacingError(
            title: "Something Went Wrong",
            message: "An unexpected error occurred. Please try again.",
            iconName: "exclamationmark.triangle",
            actionLabel: "Try Again"
        )
    }
}

// MARK: - Apple Auth Models

/// Response from the /api/auth/apple endpoint (Apple Sign-In token exchange).
/// Returns a server-issued session token that the app uses as its Bearer token
/// for subsequent API calls, along with basic user info.
struct AppleAuthResponse: Codable {
    let success: Bool
    let sessionToken: String?
    let userId: String?
    let email: String?
    let name: String?
    let error: String?
}

/// Response from the /api/auth/connect-gmail endpoint.
/// After an Apple Sign-In user connects Gmail, returns the Gmail OAuth tokens
/// and the Gmail email address for display in the UI.
struct ConnectGmailResponse: Codable {
    let success: Bool
    let email: String?
    let accessToken: String?
    let refreshToken: String?
    let expiresIn: Int?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case success
        case email
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case error
    }
}

// MARK: - User Info

/// User information from Google OAuth
struct UserInfo: Codable {
    let email: String
    let name: String?
    let picture: String?

    var displayName: String {
        return name ?? email
    }
}
