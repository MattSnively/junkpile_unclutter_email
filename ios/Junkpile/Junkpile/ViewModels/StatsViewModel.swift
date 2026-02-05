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

        // Load weekly data for charts
        loadWeeklyData(context: context)

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
