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

    /// Gmail API's pre-sanitized snippet — plain text preview with no HTML/CSS.
    /// Preferred over stripping HTML from htmlBody to avoid CSS leakage in previews.
    let snippet: String?

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
    /// RFC 8058 one-click unsubscribe header (indicates reliable unsubscribe support)
    let listUnsubscribePost: String?

    enum CodingKeys: String, CodingKey {
        case from
        case listUnsubscribe = "listUnsubscribe"
        case listUnsubscribePost = "listUnsubscribePost"
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
    /// Details of the server-side unsubscribe execution attempt (nil for "keep" decisions)
    let unsubscribeResult: UnsubscribeResult?
}

/// Result details from the server's unsubscribe execution attempt.
/// Reports which method succeeded (or if all methods failed) and what was tried.
struct UnsubscribeResult: Codable {
    /// Whether any unsubscribe method succeeded
    let success: Bool
    /// The method that worked: "rfc8058", "http-header", "http-body", "mailto", or nil
    let method: String?
    /// All methods attempted in cascade order
    let attempted: [String]?
    /// Error message if all methods failed
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

/// Error body the API returns alongside any non-2xx status.
///
/// `code` is the backend's stable taxonomy and is what the app branches on.
/// `error` is human-readable text kept for older clients, and is never shown
/// verbatim — the app picks its own wording so it can stay actionable.
struct APIErrorBody: Codable {
    let code: String?
    let error: String?
    let retryAfterSeconds: Int?

    enum CodingKeys: String, CodingKey {
        case code
        case error
        case retryAfterSeconds = "retry_after_seconds"
    }
}

/// Custom error types for API operations
enum APIError: Error, LocalizedError {
    case networkError(String)
    case authenticationRequired
    case tokenExpired
    case invalidResponse
    case serverError(String)
    case noEmailsFound
    case gmailNotConfigured

    /// Gmail has never been linked, or was unlinked. Fix: connect Gmail.
    case gmailNotConnected

    /// Gmail was linked but the grant is dead or missing a scope.
    /// Fix: re-run the Gmail authorisation.
    case gmailReauthRequired

    /// Gmail is throttling us. Fix: wait out the countdown.
    case rateLimited(retryAfterSeconds: Int)

    /// Gmail was reachable but the request failed for a non-auth reason.
    case emailFetchFailed

    /// Default wait before retrying when the server does not name one.
    static let defaultRetryAfterSeconds = 60

    /// Translates a backend error response into a typed error.
    ///
    /// Falls back to the HTTP status when the code is missing or unknown, so
    /// an older server build, a proxy error page, or a code added later still
    /// produces something the UI can act on.
    static func from(body: APIErrorBody?, statusCode: Int) -> APIError {
        switch body?.code {
        case "AUTH_REQUIRED":
            return .authenticationRequired
        case "AUTH_INVALID":
            return .tokenExpired
        case "OAUTH_TOKEN_EXPIRED", "OAUTH_SCOPE_INSUFFICIENT":
            return .gmailReauthRequired
        case "GMAIL_NOT_CONNECTED":
            return .gmailNotConnected
        case "RATE_LIMITED":
            return .rateLimited(retryAfterSeconds: body?.retryAfterSeconds ?? defaultRetryAfterSeconds)
        case "EMAIL_FETCH_FAILED":
            return .emailFetchFailed
        case "SERVER_NOT_CONFIGURED":
            return .gmailNotConfigured
        case "SERVER_INTERNAL_ERROR", "VALIDATION_ERROR", "NOT_FOUND":
            return .serverError(body?.error ?? "HTTP \(statusCode)")
        default:
            switch statusCode {
            case 401:
                return .authenticationRequired
            case 403:
                return .tokenExpired
            case 429:
                return .rateLimited(retryAfterSeconds: body?.retryAfterSeconds ?? defaultRetryAfterSeconds)
            default:
                return .serverError(body?.error ?? "HTTP \(statusCode)")
            }
        }
    }

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
        case .gmailNotConnected:
            return "Gmail is not connected"
        case .gmailReauthRequired:
            return "Gmail access needs to be renewed"
        case .rateLimited(let seconds):
            return "Gmail is rate-limiting requests. Try again in \(seconds) seconds."
        case .emailFetchFailed:
            return "Could not reach Gmail"
        }
    }
}

// MARK: - User-Facing Error

/// What the primary button on an error screen actually does.
///
/// The label alone is not enough: "Reconnect Gmail" and "Try Again" need to
/// run different code, so the button carries its intent rather than leaving
/// every error screen to re-run the same retry closure.
enum RecoveryAction: Equatable {
    /// Re-run whatever failed
    case retry
    /// Send the user back through sign-in
    case signIn
    /// Re-run Gmail authorisation
    case connectGmail
    /// Show what they have achieved so far
    case showStats
    /// Leave the failed screen for the home tab
    case goHome
}

/// Maps raw API errors to friendly, actionable messages for the UI.
/// Each error type gets a human-readable title, guidance message,
/// SF Symbol icon, an action label, and the action that label performs.
struct UserFacingError: Equatable {
    /// Short headline displayed prominently (e.g. "No Connection")
    let title: String

    /// Guidance text explaining what happened and what the user can do
    let message: String

    /// SF Symbol name for the error illustration
    let iconName: String

    /// Label for the primary action button (e.g. "Try Again", "Sign In")
    let actionLabel: String

    /// What the primary button does when tapped
    let action: RecoveryAction

    /// Seconds to hold the button disabled before the action becomes
    /// available. Set when retrying immediately would fail again — a Gmail
    /// rate limit, or a server error we should back off from.
    let retryAfterSeconds: Int?

    init(
        title: String,
        message: String,
        iconName: String,
        actionLabel: String,
        action: RecoveryAction,
        retryAfterSeconds: Int? = nil
    ) {
        self.title = title
        self.message = message
        self.iconName = iconName
        self.actionLabel = actionLabel
        self.action = action
        self.retryAfterSeconds = retryAfterSeconds
    }

    /// How long to wait before letting the user retry a server error.
    /// Short enough not to feel punitive, long enough to stop hammering a
    /// server that is already struggling.
    private static let serverErrorBackoffSeconds = 5

    /// Converts a typed APIError into a user-friendly error representation.
    /// Each case maps to a specific title/message/icon/action combo.
    static func from(_ error: APIError) -> UserFacingError {
        switch error {
        case .networkError:
            return UserFacingError(
                title: "No Connection",
                message: "Check your Wi-Fi or cellular connection and try again.",
                iconName: "wifi.slash",
                actionLabel: "Try Again",
                action: .retry
            )
        case .authenticationRequired:
            return UserFacingError(
                title: "Sign-In Required",
                message: "Please sign in to access your emails.",
                iconName: "person.crop.circle.badge.exclamationmark",
                actionLabel: "Sign In",
                action: .signIn
            )
        case .tokenExpired:
            return UserFacingError(
                title: "Session Expired",
                message: "Your session has expired. Please sign in again.",
                iconName: "clock.badge.exclamationmark",
                actionLabel: "Sign In",
                action: .signIn
            )
        case .invalidResponse:
            return UserFacingError(
                title: "Something Went Wrong",
                message: "We got an unexpected response. Please try again.",
                iconName: "exclamationmark.bubble",
                actionLabel: "Try Again",
                action: .retry
            )
        case .serverError:
            return UserFacingError(
                title: "Server Trouble",
                message: "Our servers are having a moment. Give it a few seconds.",
                iconName: "server.rack",
                actionLabel: "Try Again",
                action: .retry,
                retryAfterSeconds: serverErrorBackoffSeconds
            )
        case .noEmailsFound:
            return UserFacingError(
                title: "Inbox Already Clean",
                message: "Nothing left to unsubscribe from. Take a look at what you have cleared.",
                iconName: "sparkles",
                actionLabel: "See Your Stats",
                action: .showStats
            )
        case .gmailNotConfigured:
            // Server-side misconfiguration — nothing the user can fix, so do
            // not send them to Settings looking for a switch that isn't there.
            return UserFacingError(
                title: "Gmail Unavailable",
                message: "Email access isn't available right now. This one is on us — please try again later.",
                iconName: "envelope.badge.shield.half.filled",
                actionLabel: "Go Home",
                action: .goHome
            )
        case .gmailNotConnected:
            return UserFacingError(
                title: "Connect Gmail",
                message: "Link your Gmail account and we'll find the subscriptions cluttering your inbox.",
                iconName: "envelope.badge",
                actionLabel: "Connect Gmail",
                action: .connectGmail
            )
        case .gmailReauthRequired:
            return UserFacingError(
                title: "Reconnect Gmail",
                message: "Gmail access expired. Reconnect and we'll pick up where you left off.",
                iconName: "arrow.clockwise.circle",
                actionLabel: "Reconnect Gmail",
                action: .connectGmail
            )
        case .rateLimited(let seconds):
            return UserFacingError(
                title: "Slow Down a Moment",
                message: "Gmail is limiting how fast we can read your inbox. This clears on its own.",
                iconName: "hourglass",
                actionLabel: "Try Again",
                action: .retry,
                retryAfterSeconds: seconds
            )
        case .emailFetchFailed:
            return UserFacingError(
                title: "Couldn't Reach Gmail",
                message: "We couldn't load your inbox just now. Your decisions are safe.",
                iconName: "exclamationmark.icloud",
                actionLabel: "Try Again",
                action: .retry
            )
        }
    }

    /// Fallback error for unexpected/untyped errors
    static func generic() -> UserFacingError {
        return UserFacingError(
            title: "Something Went Wrong",
            message: "An unexpected error occurred. Please try again.",
            iconName: "exclamationmark.triangle",
            actionLabel: "Try Again",
            action: .retry
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
