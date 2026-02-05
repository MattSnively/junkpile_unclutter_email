import Foundation
import SwiftData

/// DecisionAction represents the two possible actions a user can take on an email.
enum DecisionAction: String, Codable {
    /// User chose to unsubscribe from this email sender
    case unsubscribe

    /// User chose to keep receiving emails from this sender
    case keep
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
