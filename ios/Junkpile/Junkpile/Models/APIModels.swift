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
