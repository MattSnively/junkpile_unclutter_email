import Foundation
import SwiftData

/// DailyActivity tracks user activity for a specific calendar day.
/// Used for calculating streaks and displaying weekly/monthly activity patterns.
@Model
final class DailyActivity {

    // MARK: - Properties

    /// Unique identifier for this activity record
    var id: UUID

    /// The calendar date this activity is for (time component stripped)
    var date: Date

    /// Number of emails processed on this day
    var emailsProcessed: Int

    /// Number of unsubscribes on this day
    var unsubscribeCount: Int

    /// Number of keeps on this day
    var keepCount: Int

    /// Total points earned on this day
    var pointsEarned: Int

    /// Total XP earned on this day
    var xpEarned: Int

    /// Number of sessions started on this day
    var sessionsCount: Int

    /// Whether this day counts toward the streak (at least one decision made)
    var countsTowardStreak: Bool

    // MARK: - Initialization

    /// Creates a new DailyActivity record for the specified date.
    /// - Parameter date: The calendar date (time will be stripped to start of day)
    init(date: Date) {
        self.id = UUID()
        self.date = Calendar.current.startOfDay(for: date)
        self.emailsProcessed = 0
        self.unsubscribeCount = 0
        self.keepCount = 0
        self.pointsEarned = 0
        self.xpEarned = 0
        self.sessionsCount = 0
        self.countsTowardStreak = false
    }

    // MARK: - Methods

    /// Records a decision in the daily activity.
    /// - Parameter decision: The Decision to record
    func recordDecision(_ decision: Decision) {
        emailsProcessed += 1
        pointsEarned += decision.pointsAwarded
        xpEarned += decision.xpAwarded

        switch decision.action {
        case .unsubscribe:
            unsubscribeCount += 1
        case .keep:
            keepCount += 1
        }

        // Any decision counts toward the streak
        countsTowardStreak = true
    }

    /// Reverses a decision that was undone by the user.
    /// Decrements the counts and rewards that were added by recordDecision().
    /// Uses max(0, ...) to prevent negative values from edge cases.
    /// - Parameter decision: The Decision being undone
    func reverseDecision(_ decision: Decision) {
        emailsProcessed = max(0, emailsProcessed - 1)
        pointsEarned -= decision.pointsAwarded
        xpEarned -= decision.xpAwarded

        switch decision.action {
        case .unsubscribe:
            unsubscribeCount = max(0, unsubscribeCount - 1)
        case .keep:
            keepCount = max(0, keepCount - 1)
        }

        // Note: We do NOT reset countsTowardStreak here even if emailsProcessed
        // reaches 0. Streaks are daily-level and the user did interact today.
    }

    /// Increments the session count for this day.
    func recordSessionStart() {
        sessionsCount += 1
    }

    // MARK: - Static Helpers

    /// Returns the date key (start of day) for a given date.
    /// Used to find or create the DailyActivity for a specific day.
    /// - Parameter date: Any date/time
    /// - Returns: The start of day for that date
    static func dateKey(for date: Date) -> Date {
        return Calendar.current.startOfDay(for: date)
    }

    /// Checks if two dates are on the same calendar day.
    /// - Parameters:
    ///   - date1: First date to compare
    ///   - date2: Second date to compare
    /// - Returns: True if both dates are on the same calendar day
    static func isSameDay(_ date1: Date, _ date2: Date) -> Bool {
        return Calendar.current.isDate(date1, inSameDayAs: date2)
    }

    /// Checks if two dates are consecutive calendar days.
    /// - Parameters:
    ///   - earlier: The earlier date
    ///   - later: The later date
    /// - Returns: True if later is exactly one day after earlier
    static func isConsecutiveDay(earlier: Date, later: Date) -> Bool {
        let calendar = Calendar.current
        guard let nextDay = calendar.date(byAdding: .day, value: 1, to: earlier) else {
            return false
        }
        return calendar.isDate(nextDay, inSameDayAs: later)
    }
}

// MARK: - Weekly Summary

/// Summary of activity for a week, used in charts and statistics
struct WeeklyActivitySummary {
    let weekStartDate: Date
    let dailyActivities: [DailyActivity]

    /// Total emails processed this week
    var totalEmails: Int {
        dailyActivities.reduce(0) { $0 + $1.emailsProcessed }
    }

    /// Total unsubscribes this week
    var totalUnsubscribes: Int {
        dailyActivities.reduce(0) { $0 + $1.unsubscribeCount }
    }

    /// Total keeps this week
    var totalKeeps: Int {
        dailyActivities.reduce(0) { $0 + $1.keepCount }
    }

    /// Total points earned this week
    var totalPoints: Int {
        dailyActivities.reduce(0) { $0 + $1.pointsEarned }
    }

    /// Number of active days (days with at least one decision)
    var activeDays: Int {
        dailyActivities.filter { $0.countsTowardStreak }.count
    }
}
