import Foundation
import SwiftData

/// PlayerProfile stores the user's gamification progress including XP, level, and lifetime statistics.
/// This model persists across sessions and tracks overall progress in the app.
@Model
final class PlayerProfile {

    // MARK: - Properties

    /// Unique identifier for the profile (typically one per user)
    var id: UUID

    /// User's email address from Google OAuth
    var email: String

    /// Display name from Google account
    var displayName: String

    /// Total experience points accumulated across all sessions
    var totalXP: Int

    /// Current level (calculated from totalXP)
    var currentLevel: Int

    /// Total points earned (separate from XP for gamification display)
    var totalPoints: Int

    /// Lifetime count of emails unsubscribed from
    var lifetimeUnsubscribes: Int

    /// Lifetime count of emails kept
    var lifetimeKeeps: Int

    /// Total number of sessions completed
    var totalSessionsCompleted: Int

    /// Current streak (consecutive days of activity)
    var currentStreak: Int

    /// Longest streak ever achieved
    var longestStreak: Int

    /// Date of last activity (for streak calculation)
    var lastActivityDate: Date?

    /// Date the profile was created
    var createdAt: Date

    // MARK: - Initialization

    /// Creates a new PlayerProfile with default starting values.
    /// - Parameters:
    ///   - email: User's email address from Google OAuth
    ///   - displayName: Display name from Google account
    init(email: String, displayName: String) {
        self.id = UUID()
        self.email = email
        self.displayName = displayName
        self.totalXP = 0
        self.currentLevel = 1
        self.totalPoints = 0
        self.lifetimeUnsubscribes = 0
        self.lifetimeKeeps = 0
        self.totalSessionsCompleted = 0
        self.currentStreak = 0
        self.longestStreak = 0
        self.lastActivityDate = nil
        self.createdAt = Date()
    }

    // MARK: - Level Calculation

    /// XP thresholds for each level. Each index represents the total XP needed to reach that level.
    /// Level 1 = 0 XP, Level 2 = 100 XP, Level 3 = 250 XP, etc.
    static let levelThresholds: [Int] = [
        0,      // Level 1
        100,    // Level 2
        250,    // Level 3
        500,    // Level 4
        850,    // Level 5
        1300,   // Level 6
        1900,   // Level 7
        2650,   // Level 8
        3550,   // Level 9
        4600,   // Level 10
        5800,   // Level 11
        7150,   // Level 12
        8650,   // Level 13
        10300,  // Level 14
        12100,  // Level 15
        14050,  // Level 16
        16150,  // Level 17
        18400,  // Level 18
        20800,  // Level 19
        23350   // Level 20 (max)
    ]

    /// Calculates the level based on total XP using the level thresholds.
    /// - Parameter xp: Total XP to calculate level for
    /// - Returns: The level corresponding to that XP amount
    static func calculateLevel(forXP xp: Int) -> Int {
        // Find the highest level threshold that the XP meets
        for (index, threshold) in levelThresholds.enumerated().reversed() {
            if xp >= threshold {
                return index + 1
            }
        }
        return 1
    }

    /// Returns the XP needed to reach the next level.
    /// - Returns: XP remaining to next level, or 0 if at max level
    var xpToNextLevel: Int {
        guard currentLevel < PlayerProfile.levelThresholds.count else {
            return 0 // Already at max level
        }
        let nextLevelThreshold = PlayerProfile.levelThresholds[currentLevel]
        return max(0, nextLevelThreshold - totalXP)
    }

    /// Returns the progress percentage toward the next level (0.0 to 1.0).
    var levelProgress: Double {
        guard currentLevel < PlayerProfile.levelThresholds.count else {
            return 1.0 // Max level, full progress
        }

        let currentLevelThreshold = PlayerProfile.levelThresholds[currentLevel - 1]
        let nextLevelThreshold = PlayerProfile.levelThresholds[currentLevel]
        let xpInCurrentLevel = totalXP - currentLevelThreshold
        let xpNeededForLevel = nextLevelThreshold - currentLevelThreshold

        return Double(xpInCurrentLevel) / Double(xpNeededForLevel)
    }

    /// Total number of emails processed (unsubscribes + keeps)
    var totalEmailsProcessed: Int {
        return lifetimeUnsubscribes + lifetimeKeeps
    }

    /// Unsubscribe rate as a percentage (0-100)
    var unsubscribeRate: Double {
        guard totalEmailsProcessed > 0 else { return 0 }
        return (Double(lifetimeUnsubscribes) / Double(totalEmailsProcessed)) * 100
    }
}
