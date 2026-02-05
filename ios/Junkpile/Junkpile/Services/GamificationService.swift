import Foundation
import SwiftData

/// GamificationService handles all points, XP, achievements, and streak logic.
/// Coordinates with SwiftData models to persist gamification state.
final class GamificationService {

    // MARK: - Properties

    /// SwiftData model context for persistence
    private let modelContext: ModelContext

    /// Cache of unlocked achievement IDs for quick lookup
    private var unlockedAchievementIds: Set<String> = []

    // MARK: - Initialization

    /// Creates a new GamificationService with the given model context.
    /// - Parameter modelContext: The SwiftData model context for persistence
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadUnlockedAchievements()
    }

    // MARK: - Decision Rewards

    /// Awards points and XP for a single decision.
    /// - Parameter decision: The decision to award rewards for
    func awardDecision(_ decision: Decision) {
        guard let profile = getCurrentProfile() else { return }

        // Add points and XP to profile
        profile.totalPoints += decision.pointsAwarded
        profile.totalXP += decision.xpAwarded

        // Update level based on new XP
        let newLevel = PlayerProfile.calculateLevel(forXP: profile.totalXP)
        if newLevel > profile.currentLevel {
            profile.currentLevel = newLevel
            checkLevelAchievements(level: newLevel)
        }

        // Update lifetime counts
        switch decision.action {
        case .unsubscribe:
            profile.lifetimeUnsubscribes += 1
            checkUnsubscribeMilestones(count: profile.lifetimeUnsubscribes)
        case .keep:
            profile.lifetimeKeeps += 1
        }

        // Check for first decision achievement
        if profile.totalEmailsProcessed == 1 {
            unlockAchievement(.firstStep)
        }

        // Update streak
        updateStreak()

        // Save changes
        try? modelContext.save()
    }

    // MARK: - Session Achievements

    /// Checks and awards session-based achievements when a session completes.
    /// - Parameter session: The completed session to check
    func checkSessionAchievements(session: Session) {
        guard let profile = getCurrentProfile() else { return }

        // Getting Started - First completed session
        if profile.totalSessionsCompleted == 0 {
            unlockAchievement(.gettingStarted)
        }

        // No Mercy - Unsubscribed from all emails in a session (min 5 emails)
        if session.isNoMercySession && session.totalEmails >= 5 {
            unlockAchievement(.noMercy)
        }

        // Loyal Subscriber - Kept all emails in a session (min 5 emails)
        if session.isCompleted && session.totalEmails >= 5 && session.unsubscribeCount == 0 {
            unlockAchievement(.loyalSubscriber)
        }

        // Session count milestones
        let newSessionCount = profile.totalSessionsCompleted + 1
        checkSessionMilestones(count: newSessionCount)
    }

    /// Updates profile statistics after a session completes.
    /// - Parameter session: The completed session
    func updateProfileStats(session: Session) {
        guard let profile = getCurrentProfile() else { return }

        profile.totalSessionsCompleted += 1
        profile.lastActivityDate = Date()

        try? modelContext.save()
    }

    // MARK: - Streak Management

    /// Updates the user's streak based on their last activity date.
    func updateStreak() {
        guard let profile = getCurrentProfile() else { return }

        let today = Calendar.current.startOfDay(for: Date())

        if let lastActivity = profile.lastActivityDate {
            let lastActivityDay = Calendar.current.startOfDay(for: lastActivity)

            if Calendar.current.isDate(lastActivityDay, inSameDayAs: today) {
                // Already active today, no change to streak
                return
            }

            if DailyActivity.isConsecutiveDay(earlier: lastActivityDay, later: today) {
                // Consecutive day, increment streak
                profile.currentStreak += 1

                // Update longest streak if needed
                if profile.currentStreak > profile.longestStreak {
                    profile.longestStreak = profile.currentStreak
                }

                // Check streak achievements
                checkStreakAchievements(streak: profile.currentStreak)
            } else {
                // Streak broken, reset to 1
                profile.currentStreak = 1
            }
        } else {
            // First activity ever
            profile.currentStreak = 1
        }

        profile.lastActivityDate = Date()
        try? modelContext.save()
    }

    // MARK: - Achievement Management

    /// Unlocks an achievement if not already unlocked.
    /// - Parameter achievement: The achievement to unlock
    /// - Returns: True if the achievement was newly unlocked
    @discardableResult
    func unlockAchievement(_ achievement: Achievement) -> Bool {
        // Check if already unlocked
        if unlockedAchievementIds.contains(achievement.rawValue) {
            return false
        }

        // Create unlock record
        let unlocked = UnlockedAchievement(achievement: achievement)
        modelContext.insert(unlocked)

        // Update cache
        unlockedAchievementIds.insert(achievement.rawValue)

        // Award bonus points
        if let profile = getCurrentProfile() {
            profile.totalPoints += achievement.pointsBonus
        }

        try? modelContext.save()

        // Post notification for UI updates
        NotificationCenter.default.post(
            name: .achievementUnlocked,
            object: achievement
        )

        return true
    }

    /// Checks if an achievement is unlocked.
    /// - Parameter achievement: The achievement to check
    /// - Returns: True if unlocked
    func isAchievementUnlocked(_ achievement: Achievement) -> Bool {
        return unlockedAchievementIds.contains(achievement.rawValue)
    }

    /// Gets all unlocked achievements.
    /// - Returns: Array of UnlockedAchievement records
    func getUnlockedAchievements() -> [UnlockedAchievement] {
        return modelContext.getUnlockedAchievements()
    }

    /// Gets achievements that haven't been seen by the user yet.
    /// - Returns: Array of unseen UnlockedAchievement records
    func getUnseenAchievements() -> [UnlockedAchievement] {
        return getUnlockedAchievements().filter { !$0.hasBeenSeen }
    }

    /// Marks an achievement as seen.
    /// - Parameter achievement: The achievement to mark as seen
    func markAchievementAsSeen(_ achievement: Achievement) {
        let unlocked = getUnlockedAchievements().first { $0.achievementId == achievement.rawValue }
        unlocked?.hasBeenSeen = true
        try? modelContext.save()
    }

    // MARK: - Private Methods

    /// Loads unlocked achievements into the cache.
    private func loadUnlockedAchievements() {
        let unlocked = modelContext.getUnlockedAchievements()
        unlockedAchievementIds = Set(unlocked.map { $0.achievementId })
    }

    /// Gets the current user's profile.
    /// - Returns: The PlayerProfile, or nil if not found
    private func getCurrentProfile() -> PlayerProfile? {
        guard let email = KeychainService.shared.getUserEmail() else { return nil }

        let descriptor = FetchDescriptor<PlayerProfile>(
            predicate: #Predicate { $0.email == email }
        )

        return try? modelContext.fetch(descriptor).first
    }

    /// Checks and awards unsubscribe milestone achievements.
    /// - Parameter count: Current lifetime unsubscribe count
    private func checkUnsubscribeMilestones(count: Int) {
        switch count {
        case 10:
            unlockAchievement(.inboxZeroHero)
        case 25:
            unlockAchievement(.cleanSweep)
        case 50:
            unlockAchievement(.emailAssassin)
        case 100:
            unlockAchievement(.masterDeclutterer)
        case 250:
            unlockAchievement(.inboxLegend)
        case 500:
            unlockAchievement(.emailExterminator)
        default:
            break
        }
    }

    /// Checks and awards session count achievements.
    /// - Parameter count: Current session count
    private func checkSessionMilestones(count: Int) {
        switch count {
        case 5:
            unlockAchievement(.dedicatedCleaner)
        case 25:
            unlockAchievement(.sessionVeteran)
        case 100:
            unlockAchievement(.sessionMaster)
        default:
            break
        }
    }

    /// Checks and awards streak achievements.
    /// - Parameter streak: Current streak count
    private func checkStreakAchievements(streak: Int) {
        switch streak {
        case 3:
            unlockAchievement(.gettingIntoIt)
        case 7:
            unlockAchievement(.weekWarrior)
        case 14:
            unlockAchievement(.twoWeekTitan)
        case 30:
            unlockAchievement(.monthlyMaster)
        default:
            break
        }
    }

    /// Checks and awards level achievements.
    /// - Parameter level: New level reached
    private func checkLevelAchievements(level: Int) {
        switch level {
        case 5:
            unlockAchievement(.risingCleanser)
        case 10:
            unlockAchievement(.expertOrganizer)
        case 15:
            unlockAchievement(.eliteUnsubscriber)
        case 20:
            unlockAchievement(.inboxGrandmaster)
        default:
            break
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// Posted when an achievement is unlocked
    static let achievementUnlocked = Notification.Name("achievementUnlocked")
}

// MARK: - Point Constants

extension GamificationService {

    /// Points awarded for unsubscribing from an email
    static let unsubscribePoints: Int = 10

    /// Points awarded for keeping an email subscription
    static let keepPoints: Int = 5

    /// XP awarded for unsubscribing from an email
    static let unsubscribeXP: Int = 15

    /// XP awarded for keeping an email subscription
    static let keepXP: Int = 10
}
