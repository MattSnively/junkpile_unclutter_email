import Foundation
import SwiftData

/// StatsViewModel aggregates session data and prepares chart data for the statistics view.
@MainActor
final class StatsViewModel: ObservableObject {

    // MARK: - Published State

    /// Weekly activity data for charts
    @Published var weeklyData: [DailyChartData] = []

    /// Recent sessions for history list
    @Published var recentSessions: [SessionSummary] = []

    /// Total lifetime unsubscribes
    @Published var totalUnsubscribes: Int = 0

    /// Total lifetime keeps
    @Published var totalKeeps: Int = 0

    /// Total sessions completed
    @Published var totalSessions: Int = 0

    /// Unsubscribe rate percentage
    @Published var unsubscribeRate: Double = 0

    /// Previous week's activity data for week-over-week comparison
    @Published var previousWeekData: [DailyChartData] = []

    /// Whether data is loading
    @Published var isLoading = false

    // MARK: - Private Properties

    /// SwiftData model context
    private var modelContext: ModelContext?

    // MARK: - Configuration

    /// Configures the view model with a model context.
    /// - Parameter context: The SwiftData model context
    func configure(with context: ModelContext) {
        self.modelContext = context
        loadData()
    }

    // MARK: - Data Loading

    /// Loads all statistics data from persistence.
    func loadData() {
        guard let context = modelContext else { return }

        isLoading = true

        // Load weekly data for charts (current and previous week)
        loadWeeklyData(context: context)
        loadPreviousWeekData(context: context)

        // Load recent sessions
        loadRecentSessions(context: context)

        // Load lifetime stats from profile
        loadLifetimeStats(context: context)

        isLoading = false
    }

    /// Refreshes all data.
    func refresh() {
        loadData()
    }

    // MARK: - Session Deletion

    /// Deletes a session by ID and adjusts the player profile's lifetime stats.
    /// Reverses unsubscribes, keeps, points, XP, and session count on the profile.
    /// Recalculates level from adjusted XP. Cascade deletes all associated Decisions.
    /// Does NOT adjust streak or DailyActivity data — reversing historical streaks
    /// is too complex and error-prone.
    /// - Parameter sessionId: The UUID of the session to delete
    func deleteSession(id sessionId: UUID) {
        guard let context = modelContext else { return }

        // Fetch the actual Session model object from SwiftData
        let descriptor = FetchDescriptor<Session>(
            predicate: #Predicate { $0.id == sessionId }
        )

        guard let session = try? context.fetch(descriptor).first else { return }

        // Adjust PlayerProfile lifetime stats to undo this session's contributions
        if let email = KeychainService.shared.getUserEmail() {
            let profileDescriptor = FetchDescriptor<PlayerProfile>(
                predicate: #Predicate { $0.email == email }
            )

            if let profile = try? context.fetch(profileDescriptor).first {
                // Reverse the counts — clamp to zero to prevent negative values
                profile.lifetimeUnsubscribes = max(0, profile.lifetimeUnsubscribes - session.unsubscribeCount)
                profile.lifetimeKeeps = max(0, profile.lifetimeKeeps - session.keepCount)
                profile.totalSessionsCompleted = max(0, profile.totalSessionsCompleted - 1)
                profile.totalPoints = max(0, profile.totalPoints - session.pointsEarned)
                profile.totalXP = max(0, profile.totalXP - session.xpEarned)

                // Recalculate level from the adjusted XP total
                profile.currentLevel = PlayerProfile.calculateLevel(forXP: profile.totalXP)
            }
        }

        // Delete the session — cascade rule deletes associated Decisions
        context.delete(session)

        // Save changes and reload the view data
        try? context.save()
        loadData()
    }

    // MARK: - Private Methods

    /// Loads the past 7 days of activity data.
    private func loadWeeklyData(context: ModelContext) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let weekAgo = calendar.date(byAdding: .day, value: -6, to: today) else { return }

        // Get daily activities for the past week
        let activities = context.getDailyActivities(from: weekAgo, to: today)

        // Create chart data for each day
        var chartData: [DailyChartData] = []

        for dayOffset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: weekAgo) else { continue }

            let dayActivity = activities.first { calendar.isDate($0.date, inSameDayAs: date) }

            let data = DailyChartData(
                date: date,
                unsubscribes: dayActivity?.unsubscribeCount ?? 0,
                keeps: dayActivity?.keepCount ?? 0
            )
            chartData.append(data)
        }

        weeklyData = chartData
    }

    /// Loads the previous 7-day window (days 8-14 ago) for week-over-week comparison.
    private func loadPreviousWeekData(context: ModelContext) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let prevWeekEnd = calendar.date(byAdding: .day, value: -7, to: today),
              let prevWeekStart = calendar.date(byAdding: .day, value: -13, to: today) else { return }

        let activities = context.getDailyActivities(from: prevWeekStart, to: prevWeekEnd)

        var chartData: [DailyChartData] = []
        for dayOffset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: prevWeekStart) else { continue }
            let dayActivity = activities.first { calendar.isDate($0.date, inSameDayAs: date) }
            chartData.append(DailyChartData(
                date: date,
                unsubscribes: dayActivity?.unsubscribeCount ?? 0,
                keeps: dayActivity?.keepCount ?? 0
            ))
        }
        previousWeekData = chartData
    }

    /// Loads recent session summaries.
    private func loadRecentSessions(context: ModelContext) {
        let sessions = context.getRecentSessions(limit: 10)
        recentSessions = sessions.map { SessionSummary(from: $0) }
    }

    /// Loads lifetime statistics from the player profile.
    private func loadLifetimeStats(context: ModelContext) {
        guard let email = KeychainService.shared.getUserEmail() else { return }

        let descriptor = FetchDescriptor<PlayerProfile>(
            predicate: #Predicate { $0.email == email }
        )

        if let profile = try? context.fetch(descriptor).first {
            totalUnsubscribes = profile.lifetimeUnsubscribes
            totalKeeps = profile.lifetimeKeeps
            totalSessions = profile.totalSessionsCompleted
            unsubscribeRate = profile.unsubscribeRate
        }
    }

    // MARK: - Computed Properties

    /// Total emails processed
    var totalEmails: Int {
        totalUnsubscribes + totalKeeps
    }

    /// Keep rate percentage
    var keepRate: Double {
        guard totalEmails > 0 else { return 0 }
        return (Double(totalKeeps) / Double(totalEmails)) * 100
    }

    /// Weekly total unsubscribes
    var weeklyUnsubscribes: Int {
        weeklyData.reduce(0) { $0 + $1.unsubscribes }
    }

    /// Weekly total keeps
    var weeklyKeeps: Int {
        weeklyData.reduce(0) { $0 + $1.keeps }
    }

    /// Weekly total emails
    var weeklyTotal: Int {
        weeklyUnsubscribes + weeklyKeeps
    }

    /// Most active day this week
    var mostActiveDay: DailyChartData? {
        weeklyData.max { $0.total < $1.total }
    }

    /// Average emails processed per day this week
    var weeklyAverage: Double {
        guard !weeklyData.isEmpty else { return 0 }
        return Double(weeklyTotal) / Double(weeklyData.count)
    }

    // MARK: - Week-over-Week Trending

    /// Previous week's total emails processed
    var previousWeekTotal: Int {
        previousWeekData.reduce(0) { $0 + $1.total }
    }

    /// Week-over-week percentage change in total emails processed.
    /// Returns nil if the previous week had no activity (avoid divide-by-zero).
    /// Positive = improvement, negative = decline.
    var weekOverWeekChange: Double? {
        guard previousWeekTotal > 0 else { return nil }
        return (Double(weeklyTotal - previousWeekTotal) / Double(previousWeekTotal)) * 100
    }

    /// Previous week's total unsubscribes
    var previousWeekUnsubscribes: Int {
        previousWeekData.reduce(0) { $0 + $1.unsubscribes }
    }

    /// Week-over-week percentage change in unsubscribes.
    /// Returns nil if the previous week had no unsubscribes.
    var weekOverWeekUnsubscribeChange: Double? {
        guard previousWeekUnsubscribes > 0 else { return nil }
        return (Double(weeklyUnsubscribes - previousWeekUnsubscribes) / Double(previousWeekUnsubscribes)) * 100
    }
}

// MARK: - Chart Data Types

/// Data point for daily activity charts
struct DailyChartData: Identifiable {
    let id = UUID()
    let date: Date
    let unsubscribes: Int
    let keeps: Int

    /// Total emails processed this day
    var total: Int {
        unsubscribes + keeps
    }

    /// Short day name (e.g., "Mon")
    var dayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }

    /// Whether this day is today
    var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }
}

/// Data for pie/donut charts
struct RatioChartData: Identifiable {
    let id = UUID()
    let label: String
    let value: Int
    let color: String
}
