import Foundation
import SwiftData
import Combine

/// GamificationViewModel exposes gamification data to views.
/// Manages player profile, achievements, streaks, and level progress.
@MainActor
final class GamificationViewModel: ObservableObject {

    // MARK: - Published State

    /// Current player profile
    @Published var profile: PlayerProfile?

    /// All unlocked achievements
    @Published var unlockedAchievements: [UnlockedAchievement] = []

    /// Achievements that haven't been seen yet (for showing unlock animations)
    @Published var unseenAchievements: [Achievement] = []

    /// Whether data is currently being loaded
    @Published var isLoading = false

    // MARK: - Private Properties

    /// SwiftData model context for persistence
    private var modelContext: ModelContext?

    /// Gamification service for business logic
    private var gamificationService: GamificationService?

    /// Notification observer for achievement unlocks
    private var achievementObserver: NSObjectProtocol?

    // MARK: - Initialization

    init() {
        setupNotificationObserver()
    }

    deinit {
        if let observer = achievementObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Configuration

    /// Configures the view model with a model context.
    /// - Parameter context: The SwiftData model context
    func configure(with context: ModelContext) {
        self.modelContext = context
        self.gamificationService = GamificationService(modelContext: context)
        loadData()
    }

    // MARK: - Data Loading

    /// Loads all gamification data from persistence.
    func loadData() {
        guard let context = modelContext else { return }

        isLoading = true

        // Load or create profile
        if let email = KeychainService.shared.getUserEmail() {
            let displayName = KeychainService.shared.getUserName() ?? email
            profile = context.getOrCreateProfile(email: email, displayName: displayName)
        }

        // Load unlocked achievements
        unlockedAchievements = context.getUnlockedAchievements()

        // Load unseen achievements
        unseenAchievements = unlockedAchievements
            .filter { !$0.hasBeenSeen }
            .compactMap { $0.achievement }

        isLoading = false
    }

    /// Refreshes the profile data from persistence.
    func refreshProfile() {
        guard let context = modelContext,
              let email = KeychainService.shared.getUserEmail() else { return }

        let descriptor = FetchDescriptor<PlayerProfile>(
            predicate: #Predicate { $0.email == email }
        )

        profile = try? context.fetch(descriptor).first
    }

    // MARK: - Achievement Handling

    /// Marks an achievement as seen and removes it from the unseen list.
    /// - Parameter achievement: The achievement to mark as seen
    func markAchievementSeen(_ achievement: Achievement) {
        gamificationService?.markAchievementAsSeen(achievement)
        unseenAchievements.removeAll { $0 == achievement }
    }

    /// Marks all unseen achievements as seen.
    func markAllAchievementsSeen() {
        for achievement in unseenAchievements {
            gamificationService?.markAchievementAsSeen(achievement)
        }
        unseenAchievements.removeAll()
    }

    /// Checks if a specific achievement is unlocked.
    /// - Parameter achievement: The achievement to check
    /// - Returns: True if unlocked
    func isUnlocked(_ achievement: Achievement) -> Bool {
        return gamificationService?.isAchievementUnlocked(achievement) ?? false
    }

    // MARK: - Achievement Progress

    /// Returns the progress fraction (0.0–1.0) toward unlocking a specific achievement.
    /// For already-unlocked achievements, returns 1.0.
    /// For session-behavior achievements without a numeric threshold, returns nil.
    /// - Parameter achievement: The achievement to check progress for
    /// - Returns: Progress fraction, or nil if progress is not trackable
    func progress(for achievement: Achievement) -> Double? {
        // Already unlocked = full progress
        if isUnlocked(achievement) { return 1.0 }

        // Need both a threshold and a metric to calculate progress
        guard let threshold = achievement.threshold,
              let metric = achievement.progressMetric else {
            return nil
        }

        // Look up the user's current value for this metric
        let currentValue: Int
        switch metric {
        case .totalDecisions:
            currentValue = (profile?.lifetimeUnsubscribes ?? 0) + (profile?.lifetimeKeeps ?? 0)
        case .sessions:
            currentValue = profile?.totalSessionsCompleted ?? 0
        case .unsubscribes:
            currentValue = profile?.lifetimeUnsubscribes ?? 0
        case .streak:
            // Use longest streak (the max they've ever hit) since current
            // streak resets daily and would be misleading for progress
            currentValue = profile?.longestStreak ?? 0
        case .level:
            currentValue = profile?.currentLevel ?? 1
        }

        // Clamp to 0.0–1.0
        return min(1.0, Double(currentValue) / Double(threshold))
    }

    // MARK: - Computed Properties

    /// Current level from profile
    var currentLevel: Int {
        profile?.currentLevel ?? 1
    }

    /// Total XP from profile
    var totalXP: Int {
        profile?.totalXP ?? 0
    }

    /// Total points from profile
    var totalPoints: Int {
        profile?.totalPoints ?? 0
    }

    /// Current streak from profile
    var currentStreak: Int {
        profile?.currentStreak ?? 0
    }

    /// Longest streak from profile
    var longestStreak: Int {
        profile?.longestStreak ?? 0
    }

    /// Lifetime unsubscribes from profile
    var lifetimeUnsubscribes: Int {
        profile?.lifetimeUnsubscribes ?? 0
    }

    /// Lifetime keeps from profile
    var lifetimeKeeps: Int {
        profile?.lifetimeKeeps ?? 0
    }

    /// Total sessions completed from profile
    var totalSessions: Int {
        profile?.totalSessionsCompleted ?? 0
    }

    /// Progress toward next level (0.0 to 1.0)
    var levelProgress: Double {
        profile?.levelProgress ?? 0
    }

    /// XP needed to reach next level
    var xpToNextLevel: Int {
        profile?.xpToNextLevel ?? 100
    }

    /// Number of unlocked achievements
    var unlockedCount: Int {
        unlockedAchievements.count
    }

    /// Total number of achievements
    var totalAchievements: Int {
        Achievement.allCases.count
    }

    /// Achievement progress as percentage
    var achievementProgress: Double {
        guard totalAchievements > 0 else { return 0 }
        return Double(unlockedCount) / Double(totalAchievements)
    }

    /// Unsubscribe rate as percentage
    var unsubscribeRate: Double {
        profile?.unsubscribeRate ?? 0
    }

    // MARK: - Private Methods

    /// Sets up notification observer for achievement unlocks.
    private func setupNotificationObserver() {
        achievementObserver = NotificationCenter.default.addObserver(
            forName: .achievementUnlocked,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let achievement = notification.object as? Achievement else { return }

            // Add to unseen list
            self?.unseenAchievements.append(achievement)

            // Reload achievements
            self?.loadData()
        }
    }
}

// MARK: - Display Helpers

extension GamificationViewModel {

    /// Formatted XP string (e.g., "1,250 XP")
    var formattedXP: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return (formatter.string(from: NSNumber(value: totalXP)) ?? "\(totalXP)") + " XP"
    }

    /// Formatted points string (e.g., "2,500 pts")
    var formattedPoints: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return (formatter.string(from: NSNumber(value: totalPoints)) ?? "\(totalPoints)") + " pts"
    }

    /// Level title based on current level
    var levelTitle: String {
        switch currentLevel {
        case 1...3:
            return "Inbox Novice"
        case 4...6:
            return "Email Organizer"
        case 7...9:
            return "Subscription Hunter"
        case 10...12:
            return "Inbox Master"
        case 13...15:
            return "Email Ninja"
        case 16...18:
            return "Unsubscribe Expert"
        case 19...20:
            return "Inbox Grandmaster"
        default:
            return "Email Hero"
        }
    }

    /// Streak status text
    var streakStatus: String {
        if currentStreak == 0 {
            return "Start your streak!"
        } else if currentStreak == 1 {
            return "1 day streak"
        } else {
            return "\(currentStreak) day streak"
        }
    }

    /// Whether the user has an active streak today
    var hasActiveStreakToday: Bool {
        guard let lastActivity = profile?.lastActivityDate else { return false }
        return Calendar.current.isDateInToday(lastActivity)
    }
}
