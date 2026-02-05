import Foundation
import SwiftData

/// PersistenceController manages the SwiftData ModelContainer for the app.
/// Provides a centralized point for database configuration and access.
@MainActor
final class PersistenceController {

    // MARK: - Singleton

    /// Shared instance for production use
    static let shared = PersistenceController()

    /// Preview instance with sample data for SwiftUI previews
    static let preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        controller.createSampleData()
        return controller
    }()

    // MARK: - Properties

    /// The main SwiftData model container
    let container: ModelContainer

    // MARK: - Initialization

    /// Creates a new PersistenceController.
    /// - Parameter inMemory: If true, uses in-memory storage (for previews/testing)
    init(inMemory: Bool = false) {
        // Define the schema with all model types
        let schema = Schema([
            PlayerProfile.self,
            Session.self,
            Decision.self,
            DailyActivity.self,
            UnlockedAchievement.self
        ])

        // Configure the model
        let modelConfiguration: ModelConfiguration
        if inMemory {
            // In-memory storage for previews and testing
            modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true
            )
        } else {
            // Persistent storage for production
            modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                allowsSave: true
            )
        }

        // Create the container
        do {
            container = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        } catch {
            // This is a critical failure - the app cannot function without persistence
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    // MARK: - Sample Data for Previews

    /// Creates sample data for SwiftUI previews.
    private func createSampleData() {
        let context = container.mainContext

        // Create a sample player profile
        let profile = PlayerProfile(email: "test@example.com", displayName: "Test User")
        profile.totalXP = 1250
        profile.currentLevel = 4
        profile.totalPoints = 850
        profile.lifetimeUnsubscribes = 45
        profile.lifetimeKeeps = 23
        profile.totalSessionsCompleted = 8
        profile.currentStreak = 3
        profile.longestStreak = 7
        profile.lastActivityDate = Date()

        context.insert(profile)

        // Create some sample sessions
        let session1 = Session(totalEmails: 15)
        session1.unsubscribeCount = 10
        session1.keepCount = 5
        session1.pointsEarned = 125
        session1.xpEarned = 200
        session1.isCompleted = true
        session1.endTime = Date()

        let session2 = Session(totalEmails: 20)
        session2.unsubscribeCount = 18
        session2.keepCount = 2
        session2.pointsEarned = 190
        session2.xpEarned = 290
        session2.isCompleted = true
        session2.endTime = Date().addingTimeInterval(-86400) // Yesterday

        context.insert(session1)
        context.insert(session2)

        // Create some sample achievements
        let achievements: [Achievement] = [.firstStep, .gettingStarted, .inboxZeroHero, .gettingIntoIt]
        for achievement in achievements {
            let unlocked = UnlockedAchievement(achievement: achievement)
            unlocked.hasBeenSeen = true
            context.insert(unlocked)
        }

        // Create sample daily activities for the past week
        let calendar = Calendar.current
        for dayOffset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) else { continue }

            let activity = DailyActivity(date: date)
            activity.emailsProcessed = Int.random(in: 5...20)
            activity.unsubscribeCount = Int.random(in: 3...15)
            activity.keepCount = activity.emailsProcessed - activity.unsubscribeCount
            activity.pointsEarned = (activity.unsubscribeCount * 10) + (activity.keepCount * 5)
            activity.xpEarned = (activity.unsubscribeCount * 15) + (activity.keepCount * 10)
            activity.sessionsCount = Int.random(in: 1...3)
            activity.countsTowardStreak = true

            context.insert(activity)
        }

        // Save the sample data
        do {
            try context.save()
        } catch {
            print("Failed to save sample data: \(error)")
        }
    }
}

// MARK: - Model Context Extensions

extension ModelContext {

    /// Fetches the player profile, creating one if it doesn't exist.
    /// - Parameters:
    ///   - email: User's email address
    ///   - displayName: User's display name
    /// - Returns: The PlayerProfile for this user
    func getOrCreateProfile(email: String, displayName: String) -> PlayerProfile {
        let descriptor = FetchDescriptor<PlayerProfile>(
            predicate: #Predicate { $0.email == email }
        )

        if let existingProfile = try? fetch(descriptor).first {
            return existingProfile
        }

        // Create a new profile
        let newProfile = PlayerProfile(email: email, displayName: displayName)
        insert(newProfile)
        return newProfile
    }

    /// Fetches the DailyActivity for a specific date, creating one if it doesn't exist.
    /// - Parameter date: The date to get activity for
    /// - Returns: The DailyActivity for that date
    func getOrCreateDailyActivity(for date: Date) -> DailyActivity {
        let startOfDay = Calendar.current.startOfDay(for: date)

        let descriptor = FetchDescriptor<DailyActivity>(
            predicate: #Predicate { $0.date == startOfDay }
        )

        if let existingActivity = try? fetch(descriptor).first {
            return existingActivity
        }

        // Create a new daily activity
        let newActivity = DailyActivity(date: date)
        insert(newActivity)
        return newActivity
    }

    /// Checks if an achievement has been unlocked.
    /// - Parameter achievement: The achievement to check
    /// - Returns: True if already unlocked
    func isAchievementUnlocked(_ achievement: Achievement) -> Bool {
        let achievementId = achievement.rawValue
        let descriptor = FetchDescriptor<UnlockedAchievement>(
            predicate: #Predicate { $0.achievementId == achievementId }
        )

        if let results = try? fetch(descriptor) {
            return !results.isEmpty
        }
        return false
    }

    /// Gets all unlocked achievements.
    /// - Returns: Array of UnlockedAchievement records
    func getUnlockedAchievements() -> [UnlockedAchievement] {
        let descriptor = FetchDescriptor<UnlockedAchievement>(
            sortBy: [SortDescriptor(\.unlockedAt, order: .reverse)]
        )

        return (try? fetch(descriptor)) ?? []
    }

    /// Gets recent sessions.
    /// - Parameter limit: Maximum number of sessions to return
    /// - Returns: Array of Session records, most recent first
    func getRecentSessions(limit: Int = 10) -> [Session] {
        var descriptor = FetchDescriptor<Session>(
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        descriptor.fetchLimit = limit

        return (try? fetch(descriptor)) ?? []
    }

    /// Gets daily activities for a date range.
    /// - Parameters:
    ///   - startDate: Start of the range
    ///   - endDate: End of the range
    /// - Returns: Array of DailyActivity records
    func getDailyActivities(from startDate: Date, to endDate: Date) -> [DailyActivity] {
        let start = Calendar.current.startOfDay(for: startDate)
        let end = Calendar.current.startOfDay(for: endDate)

        let descriptor = FetchDescriptor<DailyActivity>(
            predicate: #Predicate { $0.date >= start && $0.date <= end },
            sortBy: [SortDescriptor(\.date, order: .ascending)]
        )

        return (try? fetch(descriptor)) ?? []
    }
}
