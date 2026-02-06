import Foundation
import SwiftData

/// Achievement defines all available achievements in the app.
/// Each achievement has specific unlock criteria tracked by the gamification system.
enum Achievement: String, CaseIterable, Identifiable {

    // MARK: - Getting Started

    /// First decision made in the app
    case firstStep = "first_step"

    /// Complete first session
    case gettingStarted = "getting_started"

    // MARK: - Unsubscribe Milestones

    /// Unsubscribe from 10 emails
    case inboxZeroHero = "inbox_zero_hero"

    /// Unsubscribe from 25 emails
    case cleanSweep = "clean_sweep"

    /// Unsubscribe from 50 emails
    case emailAssassin = "email_assassin"

    /// Unsubscribe from 100 emails
    case masterDeclutterer = "master_declutterer"

    /// Unsubscribe from 250 emails
    case inboxLegend = "inbox_legend"

    /// Unsubscribe from 500 emails
    case emailExterminator = "email_exterminator"

    // MARK: - Session Achievements

    /// Unsubscribe from all emails in a single session (min 5 emails)
    case noMercy = "no_mercy"

    /// Keep all emails in a single session (min 5 emails)
    case loyalSubscriber = "loyal_subscriber"

    /// Complete 5 sessions
    case dedicatedCleaner = "dedicated_cleaner"

    /// Complete 25 sessions
    case sessionVeteran = "session_veteran"

    /// Complete 100 sessions
    case sessionMaster = "session_master"

    // MARK: - Streak Achievements

    /// Maintain a 3-day streak
    case gettingIntoIt = "getting_into_it"

    /// Maintain a 7-day streak
    case weekWarrior = "week_warrior"

    /// Maintain a 14-day streak
    case twoWeekTitan = "two_week_titan"

    /// Maintain a 30-day streak
    case monthlyMaster = "monthly_master"

    // MARK: - Level Achievements

    /// Reach level 5
    case risingCleanser = "rising_cleanser"

    /// Reach level 10
    case expertOrganizer = "expert_organizer"

    /// Reach level 15
    case eliteUnsubscriber = "elite_unsubscriber"

    /// Reach level 20 (max level)
    case inboxGrandmaster = "inbox_grandmaster"

    // MARK: - Identifiable

    var id: String { rawValue }

    // MARK: - Display Properties

    /// The display name of the achievement
    var title: String {
        switch self {
        case .firstStep: return "First Step"
        case .gettingStarted: return "Getting Started"
        case .inboxZeroHero: return "Inbox Zero Hero"
        case .cleanSweep: return "Clean Sweep"
        case .emailAssassin: return "Email Assassin"
        case .masterDeclutterer: return "Master Declutterer"
        case .inboxLegend: return "Inbox Legend"
        case .emailExterminator: return "Email Exterminator"
        case .noMercy: return "No Mercy"
        case .loyalSubscriber: return "Loyal Subscriber"
        case .dedicatedCleaner: return "Dedicated Cleaner"
        case .sessionVeteran: return "Session Veteran"
        case .sessionMaster: return "Session Master"
        case .gettingIntoIt: return "Getting Into It"
        case .weekWarrior: return "Week Warrior"
        case .twoWeekTitan: return "Two Week Titan"
        case .monthlyMaster: return "Monthly Master"
        case .risingCleanser: return "Rising Cleanser"
        case .expertOrganizer: return "Expert Organizer"
        case .eliteUnsubscriber: return "Elite Unsubscriber"
        case .inboxGrandmaster: return "Inbox Grandmaster"
        }
    }

    /// Description of what is required to unlock this achievement
    var description: String {
        switch self {
        case .firstStep: return "Make your first decision"
        case .gettingStarted: return "Complete your first session"
        case .inboxZeroHero: return "Unsubscribe from 10 emails"
        case .cleanSweep: return "Unsubscribe from 25 emails"
        case .emailAssassin: return "Unsubscribe from 50 emails"
        case .masterDeclutterer: return "Unsubscribe from 100 emails"
        case .inboxLegend: return "Unsubscribe from 250 emails"
        case .emailExterminator: return "Unsubscribe from 500 emails"
        case .noMercy: return "Unsubscribe from all emails in a session"
        case .loyalSubscriber: return "Keep all emails in a session"
        case .dedicatedCleaner: return "Complete 5 sessions"
        case .sessionVeteran: return "Complete 25 sessions"
        case .sessionMaster: return "Complete 100 sessions"
        case .gettingIntoIt: return "Maintain a 3-day streak"
        case .weekWarrior: return "Maintain a 7-day streak"
        case .twoWeekTitan: return "Maintain a 14-day streak"
        case .monthlyMaster: return "Maintain a 30-day streak"
        case .risingCleanser: return "Reach level 5"
        case .expertOrganizer: return "Reach level 10"
        case .eliteUnsubscriber: return "Reach level 15"
        case .inboxGrandmaster: return "Reach level 20"
        }
    }

    /// SF Symbol icon name for this achievement
    var iconName: String {
        switch self {
        case .firstStep: return "foot.fill"
        case .gettingStarted: return "checkmark.circle.fill"
        case .inboxZeroHero: return "tray.fill"
        case .cleanSweep: return "wind"
        case .emailAssassin: return "target"
        case .masterDeclutterer: return "sparkles"
        case .inboxLegend: return "star.fill"
        case .emailExterminator: return "flame.fill"
        case .noMercy: return "bolt.fill"
        case .loyalSubscriber: return "heart.fill"
        case .dedicatedCleaner: return "repeat"
        case .sessionVeteran: return "medal.fill"
        case .sessionMaster: return "crown.fill"
        case .gettingIntoIt: return "calendar"
        case .weekWarrior: return "calendar.badge.checkmark"
        case .twoWeekTitan: return "calendar.circle.fill"
        case .monthlyMaster: return "calendar.badge.exclamationmark"
        case .risingCleanser: return "arrow.up.circle"
        case .expertOrganizer: return "arrow.up.circle.fill"
        case .eliteUnsubscriber: return "star.circle"
        case .inboxGrandmaster: return "star.circle.fill"
        }
    }

    /// The numeric threshold required to unlock this achievement.
    /// Returns nil for achievements that are session-behavior-based
    /// (e.g., noMercy, loyalSubscriber) where a simple progress bar
    /// doesn't make sense.
    var threshold: Int? {
        switch self {
        // Getting Started
        case .firstStep: return 1
        case .gettingStarted: return 1
        // Unsubscribe Milestones
        case .inboxZeroHero: return 10
        case .cleanSweep: return 25
        case .emailAssassin: return 50
        case .masterDeclutterer: return 100
        case .inboxLegend: return 250
        case .emailExterminator: return 500
        // Session counts
        case .dedicatedCleaner: return 5
        case .sessionVeteran: return 25
        case .sessionMaster: return 100
        // Streak milestones
        case .gettingIntoIt: return 3
        case .weekWarrior: return 7
        case .twoWeekTitan: return 14
        case .monthlyMaster: return 30
        // Level milestones
        case .risingCleanser: return 5
        case .expertOrganizer: return 10
        case .eliteUnsubscriber: return 15
        case .inboxGrandmaster: return 20
        // Session-behavior achievements — no meaningful progress bar
        case .noMercy, .loyalSubscriber: return nil
        }
    }

    /// The category of metric this achievement tracks. Used by
    /// GamificationViewModel.progress(for:) to look up the user's
    /// current value and calculate progress toward the threshold.
    enum ProgressMetric {
        case totalDecisions
        case sessions
        case unsubscribes
        case streak
        case level
    }

    /// Which metric to read from the player profile to calculate progress.
    /// Returns nil for achievements without a simple numeric progress path.
    var progressMetric: ProgressMetric? {
        switch self {
        case .firstStep: return .totalDecisions
        case .gettingStarted: return .sessions
        case .inboxZeroHero, .cleanSweep, .emailAssassin,
             .masterDeclutterer, .inboxLegend, .emailExterminator:
            return .unsubscribes
        case .dedicatedCleaner, .sessionVeteran, .sessionMaster:
            return .sessions
        case .gettingIntoIt, .weekWarrior, .twoWeekTitan, .monthlyMaster:
            return .streak
        case .risingCleanser, .expertOrganizer, .eliteUnsubscriber, .inboxGrandmaster:
            return .level
        case .noMercy, .loyalSubscriber:
            return nil
        }
    }

    /// Points bonus awarded when achievement is unlocked
    var pointsBonus: Int {
        switch self {
        case .firstStep, .gettingStarted: return 25
        case .inboxZeroHero, .gettingIntoIt: return 50
        case .cleanSweep, .noMercy, .loyalSubscriber, .dedicatedCleaner: return 100
        case .emailAssassin, .weekWarrior, .risingCleanser: return 150
        case .masterDeclutterer, .sessionVeteran, .twoWeekTitan, .expertOrganizer: return 250
        case .inboxLegend, .monthlyMaster, .eliteUnsubscriber: return 500
        case .emailExterminator, .sessionMaster, .inboxGrandmaster: return 1000
        }
    }

    /// Category for grouping achievements in the UI
    var category: AchievementCategory {
        switch self {
        case .firstStep, .gettingStarted:
            return .gettingStarted
        case .inboxZeroHero, .cleanSweep, .emailAssassin, .masterDeclutterer, .inboxLegend, .emailExterminator:
            return .unsubscribeMilestones
        case .noMercy, .loyalSubscriber, .dedicatedCleaner, .sessionVeteran, .sessionMaster:
            return .sessions
        case .gettingIntoIt, .weekWarrior, .twoWeekTitan, .monthlyMaster:
            return .streaks
        case .risingCleanser, .expertOrganizer, .eliteUnsubscriber, .inboxGrandmaster:
            return .levels
        }
    }
}

/// Categories for grouping achievements in the gallery UI
enum AchievementCategory: String, CaseIterable, Identifiable {
    case gettingStarted = "Getting Started"
    case unsubscribeMilestones = "Unsubscribe Milestones"
    case sessions = "Sessions"
    case streaks = "Streaks"
    case levels = "Levels"

    var id: String { rawValue }

    /// Achievements belonging to this category
    var achievements: [Achievement] {
        Achievement.allCases.filter { $0.category == self }
    }
}

/// UnlockedAchievement tracks when a user unlocks a specific achievement.
/// This is stored in SwiftData to persist unlock state across sessions.
@Model
final class UnlockedAchievement {

    // MARK: - Properties

    /// Unique identifier for this unlock record
    var id: UUID

    /// The achievement ID that was unlocked (maps to Achievement enum rawValue)
    var achievementId: String

    /// When this achievement was unlocked
    var unlockedAt: Date

    /// Whether the user has seen/acknowledged this achievement unlock
    var hasBeenSeen: Bool

    // MARK: - Computed Properties

    /// The Achievement enum value for this unlock
    var achievement: Achievement? {
        return Achievement(rawValue: achievementId)
    }

    // MARK: - Initialization

    /// Creates a new UnlockedAchievement record.
    /// - Parameter achievement: The Achievement that was unlocked
    init(achievement: Achievement) {
        self.id = UUID()
        self.achievementId = achievement.rawValue
        self.unlockedAt = Date()
        self.hasBeenSeen = false
    }
}
