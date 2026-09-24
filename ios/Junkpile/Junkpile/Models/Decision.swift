import Foundation
import SwiftData

/// DecisionAction represents the two possible actions a user can take on an email.
enum DecisionAction: String, Codable {
    /// User chose to unsubscribe from this email sender
    case unsubscribe

    /// User chose to keep receiving emails from this sender
    case keep
}

/// UnsubscribeOutcome represents what actually happened to an unsubscribe request
/// server-side, as opposed to what the user asked for. Points/XP are awarded on
/// the swipe regardless of outcome — a blocked request is not the user's fault.
enum UnsubscribeOutcome: String, Codable, CaseIterable {
    /// Swiped but not yet confirmed on the session-end review, so nothing has
    /// been sent. Also where a send returns to if it never reached the server.
    case queued

    /// Sent; the API call has not completed yet
    case pending

    /// An unsubscribe endpoint accepted the request (2xx response)
    case confirmed

    /// Requests were fired but none could be verified as accepted
    case attempted

    /// The server had no usable unsubscribe method to try
    case failed

    /// Short label for stat rows and badges
    var displayName: String {
        switch self {
        case .queued: return "Not sent"
        case .pending: return "Pending"
        case .confirmed: return "Confirmed"
        case .attempted: return "Attempted"
        case .failed: return "Failed"
        }
    }

    /// Maps the server's unsubscribe execution result to an outcome.
    /// A nil result means the cascade never ran (older server versions omit
    /// the field entirely), which is indistinguishable from having nothing to try.
    static func from(_ result: UnsubscribeResult?) -> UnsubscribeOutcome {
        guard let result = result else { return .failed }
        if result.success {
            return .confirmed
        }
        return (result.attempted ?? []).isEmpty ? .failed : .attempted
    }

    /// Order in a results list: the ones the user may need to act on first
    var resultsSortOrder: Int {
        switch self {
        case .failed: return 0
        case .attempted: return 1
        case .queued: return 2
        case .pending: return 3
        case .confirmed: return 4
        }
    }
}

extension Decision {

    /// Plain-language reason for this unsubscribe's outcome, so a user can
    /// tell which senders need a manual follow-up and why.
    var outcomeExplanation: String {
        switch unsubscribeOutcome {
        case .queued:
            return "Not sent yet"
        case .pending, nil:
            return "Sent, waiting for a result"
        case .confirmed:
            switch unsubscribeMethod {
            case "rfc8058": return "Unsubscribed with the sender's one-click link"
            case "http-header", "http-body": return "Unsubscribed through the sender's unsubscribe page"
            case "mailto": return "Unsubscribed by email from your account"
            default: return "Unsubscribed"
            }
        case .attempted:
            return "Request sent, but the sender didn't confirm it. You may need to unsubscribe on their site."
        case .failed:
            return "No working unsubscribe option was found. Try the unsubscribe link in the email."
        }
    }
}

/// Decision represents a single swipe action on an email.
/// Each decision records what email was processed, what action was taken,
/// and the points/XP awarded for that action.
@Model
final class Decision {

    // MARK: - Properties

    /// Unique identifier for this decision
    var id: UUID

    /// The Gmail message ID of the email this decision was made on
    var emailId: String

    /// The sender name/address for display purposes
    var emailSender: String

    /// The subject line of the email
    var emailSubject: String

    /// The action taken (unsubscribe or keep)
    var actionRawValue: String

    /// Timestamp when the decision was made
    var timestamp: Date

    /// Points awarded for this decision
    var pointsAwarded: Int

    /// XP awarded for this decision
    var xpAwarded: Int

    /// The unsubscribe URL if the action was unsubscribe (nil for keep actions)
    var unsubscribeUrl: String?

    /// Server-side execution outcome raw value (nil for keep actions and for
    /// decisions recorded before outcome tracking shipped). Optional so existing
    /// stores migrate lightweight without a versioned schema.
    var unsubscribeOutcomeRawValue: String?

    /// The unsubscribe method that succeeded server-side ("rfc8058", "http-header",
    /// "http-body", "mailto"), nil if none did. Kept per-decision for the
    /// repeat-offender tracking planned in the PRO tier.
    var unsubscribeMethod: String?

    // MARK: - Computed Properties

    /// The action enum derived from the raw value
    var action: DecisionAction {
        get {
            return DecisionAction(rawValue: actionRawValue) ?? .keep
        }
        set {
            actionRawValue = newValue.rawValue
        }
    }

    /// The server-side outcome of the unsubscribe request.
    /// Nil for keep decisions and for legacy records that predate tracking.
    var unsubscribeOutcome: UnsubscribeOutcome? {
        get {
            guard let rawValue = unsubscribeOutcomeRawValue else { return nil }
            return UnsubscribeOutcome(rawValue: rawValue)
        }
        set {
            unsubscribeOutcomeRawValue = newValue?.rawValue
        }
    }

    // MARK: - Initialization

    /// Creates a new Decision for a given email and action.
    /// Points and XP are automatically calculated based on the action.
    /// - Parameters:
    ///   - emailId: The Gmail message ID
    ///   - emailSender: The sender name/address for display
    ///   - emailSubject: The subject line of the email
    ///   - action: The action taken (unsubscribe or keep)
    ///   - unsubscribeUrl: The unsubscribe URL if action is unsubscribe
    init(
        emailId: String,
        emailSender: String,
        emailSubject: String,
        action: DecisionAction,
        unsubscribeUrl: String? = nil
    ) {
        self.id = UUID()
        self.emailId = emailId
        self.emailSender = emailSender
        self.emailSubject = emailSubject
        self.actionRawValue = action.rawValue
        self.timestamp = Date()
        self.unsubscribeUrl = unsubscribeUrl

        // Unsubscribes wait in the queue until the user confirms them at the
        // end of the session; keep decisions have no outcome to track
        self.unsubscribeOutcomeRawValue = action == .unsubscribe
            ? UnsubscribeOutcome.queued.rawValue
            : nil
        self.unsubscribeMethod = nil

        // Calculate points and XP based on action type
        // Unsubscribe: 10 points, 15 XP (rewards decluttering)
        // Keep: 5 points, 10 XP (still rewarded for making a decision)
        switch action {
        case .unsubscribe:
            self.pointsAwarded = 10
            self.xpAwarded = 15
        case .keep:
            self.pointsAwarded = 5
            self.xpAwarded = 10
        }
    }

    // MARK: - Point Constants

    /// Points awarded for unsubscribing from an email
    static let unsubscribePoints: Int = 10

    /// Points awarded for keeping an email subscription
    static let keepPoints: Int = 5

    /// XP awarded for unsubscribing from an email
    static let unsubscribeXP: Int = 15

    /// XP awarded for keeping an email subscription
    static let keepXP: Int = 10
}

// MARK: - Decision Summary for API

/// Lightweight decision data for sending to the backend API
struct DecisionRequest: Codable {
    let emailId: String
    let decision: String

    init(from decision: Decision) {
        self.emailId = decision.emailId
        self.decision = decision.action.rawValue
    }
}
