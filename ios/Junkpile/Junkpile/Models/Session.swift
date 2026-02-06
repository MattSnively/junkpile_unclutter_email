import Foundation
import SwiftData

/// Session represents a single email-swiping session in the app.
/// A session starts when the user begins swiping and ends when they complete all emails
/// or manually exit the session.
@Model
final class Session {

    // MARK: - Properties

    /// Unique identifier for this session
    var id: UUID

    /// When this session started
    var startTime: Date

    /// When this session ended (nil if still in progress)
    var endTime: Date?

    /// Total number of emails presented in this session
    var totalEmails: Int

    /// Number of emails the user decided to unsubscribe from
    var unsubscribeCount: Int

    /// Number of emails the user decided to keep
    var keepCount: Int

    /// Points earned during this session
    var pointsEarned: Int

    /// XP earned during this session
    var xpEarned: Int

    /// Whether this session was completed (all emails processed)
    var isCompleted: Bool

    /// Decisions made during this session (relationship to Decision model)
    @Relationship(deleteRule: .cascade)
    var decisions: [Decision]

    // MARK: - Initialization

    /// Creates a new Session with the specified total emails.
    /// - Parameter totalEmails: The number of emails to be processed in this session
    init(totalEmails: Int) {
        self.id = UUID()
        self.startTime = Date()
        self.endTime = nil
        self.totalEmails = totalEmails
        self.unsubscribeCount = 0
        self.keepCount = 0
        self.pointsEarned = 0
        self.xpEarned = 0
        self.isCompleted = false
        self.decisions = []
    }

    // MARK: - Computed Properties

    /// Duration of the session in seconds
    var durationInSeconds: TimeInterval? {
        guard let endTime = endTime else { return nil }
        return endTime.timeIntervalSince(startTime)
    }

    /// Formatted duration string (e.g., "2m 30s")
    var formattedDuration: String {
        guard let duration = durationInSeconds else { return "In Progress" }

        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60

        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }

    /// Total decisions made so far (unsubscribe + keep)
    var totalDecisions: Int {
        return unsubscribeCount + keepCount
    }

    /// Progress percentage through the session (0.0 to 1.0)
    var progress: Double {
        guard totalEmails > 0 else { return 0 }
        return Double(totalDecisions) / Double(totalEmails)
    }

    /// Remaining emails to process
    var remainingEmails: Int {
        return max(0, totalEmails - totalDecisions)
    }

    /// Whether all emails in the session have been unsubscribed (for "No Mercy" achievement)
    var isNoMercySession: Bool {
        return isCompleted && totalEmails > 0 && keepCount == 0
    }

    // MARK: - Methods

    /// Marks the session as completed and records the end time.
    func complete() {
        self.endTime = Date()
        self.isCompleted = true
    }

    /// Removes a decision from this session and reverses its counters.
    /// Used by the undo system to roll back a swipe decision within
    /// the undo window. Also uncompletes the session if it was marked complete,
    /// since the user is returning to the card they just swiped.
    /// - Parameter decision: The Decision to remove
    func removeDecision(_ decision: Decision) {
        // Remove the decision from the array
        decisions.removeAll { $0.id == decision.id }

        // Reverse the action-specific count
        switch decision.action {
        case .unsubscribe:
            unsubscribeCount -= 1
        case .keep:
            keepCount -= 1
        }

        // Reverse points and XP awarded by this decision
        pointsEarned -= decision.pointsAwarded
        xpEarned -= decision.xpAwarded

        // If the session was completed (user swiped the last card and then undid it),
        // revert to in-progress so they can continue swiping
        if isCompleted {
            isCompleted = false
            endTime = nil
        }
    }

    /// Adds a decision to this session and updates counters.
    /// - Parameter decision: The Decision to add
    func addDecision(_ decision: Decision) {
        decisions.append(decision)

        // Update counts based on decision action
        switch decision.action {
        case .unsubscribe:
            unsubscribeCount += 1
        case .keep:
            keepCount += 1
        }

        // Update points and XP
        pointsEarned += decision.pointsAwarded
        xpEarned += decision.xpAwarded
    }
}

// MARK: - Session Summary

/// A lightweight summary of a session for display in lists
struct SessionSummary: Identifiable {
    let id: UUID
    let date: Date
    let totalEmails: Int
    let unsubscribeCount: Int
    let keepCount: Int
    let pointsEarned: Int
    let isCompleted: Bool

    init(from session: Session) {
        self.id = session.id
        self.date = session.startTime
        self.totalEmails = session.totalEmails
        self.unsubscribeCount = session.unsubscribeCount
        self.keepCount = session.keepCount
        self.pointsEarned = session.pointsEarned
        self.isCompleted = session.isCompleted
    }
}
