import SwiftUI

/// StreakView displays the user's current and longest streaks with visual indicators.
struct StreakView: View {

    // MARK: - Environment

    @EnvironmentObject var gamificationViewModel: GamificationViewModel

    // MARK: - Body

    var body: some View {
        VStack(spacing: 24) {
            // Current streak card
            currentStreakCard

            // Weekly activity
            weeklyActivityView

            // Streak stats
            streakStatsRow

            Spacer()
        }
        .padding()
        .background(Color(UIColor.systemGroupedBackground))
        .navigationTitle("Streaks")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Components

    /// Large current streak display
    private var currentStreakCard: some View {
        VStack(spacing: 16) {
            // Flame icon with animation
            ZStack {
                Circle()
                    .fill(streakColor.opacity(0.1))
                    .frame(width: 100, height: 100)

                Image(systemName: "flame.fill")
                    .font(.system(size: 50))
                    .foregroundColor(streakColor)
            }

            // Streak count
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text("\(gamificationViewModel.currentStreak)")
                    .font(.system(size: 60, weight: .bold, design: .rounded))
                    .foregroundColor(.black)

                Text(gamificationViewModel.currentStreak == 1 ? "day" : "days")
                    .font(.title3)
                    .foregroundColor(.gray)
            }

            // Status message
            Text(streakStatusMessage)
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
    }

    /// Weekly activity visualization (last 7 days)
    private var weeklyActivityView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("This Week")
                .font(.headline)
                .foregroundColor(.black)

            HStack(spacing: 8) {
                ForEach(0..<7, id: \.self) { dayOffset in
                    dayCircle(for: dayOffset)
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }

    /// Single day circle in the weekly view
    private func dayCircle(for dayOffset: Int) -> some View {
        let calendar = Calendar.current
        let date = calendar.date(byAdding: .day, value: -(6 - dayOffset), to: Date()) ?? Date()
        let dayName = calendar.shortWeekdaySymbols[calendar.component(.weekday, from: date) - 1]
        let isActive = isDateActive(date)
        let isToday = calendar.isDateInToday(date)

        return VStack(spacing: 6) {
            // Day indicator
            ZStack {
                Circle()
                    .fill(isActive ? Color.orange : Color.gray.opacity(0.1))
                    .frame(width: 36, height: 36)

                if isActive {
                    Image(systemName: "flame.fill")
                        .font(.caption)
                        .foregroundColor(.white)
                } else if isToday && !gamificationViewModel.hasActiveStreakToday {
                    Circle()
                        .stroke(Color.orange, style: StrokeStyle(lineWidth: 2, dash: [4]))
                        .frame(width: 32, height: 32)
                }
            }

            // Day name
            Text(dayName.prefix(1))
                .font(.caption2)
                .foregroundColor(isToday ? .black : .gray)
                .fontWeight(isToday ? .bold : .regular)
        }
        .frame(maxWidth: .infinity)
    }

    /// Row showing streak statistics
    private var streakStatsRow: some View {
        HStack(spacing: 24) {
            // Longest streak
            VStack(spacing: 8) {
                Image(systemName: "trophy.fill")
                    .font(.title2)
                    .foregroundColor(.yellow)

                Text("\(gamificationViewModel.longestStreak)")
                    .font(.title2.bold())
                    .foregroundColor(.black)

                Text("Longest Streak")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(Color.white)
            .cornerRadius(12)

            // Total active days
            VStack(spacing: 8) {
                Image(systemName: "calendar.badge.checkmark")
                    .font(.title2)
                    .foregroundColor(.green)

                Text("\(gamificationViewModel.totalSessions)")
                    .font(.title2.bold())
                    .foregroundColor(.black)

                Text("Total Sessions")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(Color.white)
            .cornerRadius(12)
        }
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }

    // MARK: - Computed Properties

    /// Color based on streak length
    private var streakColor: Color {
        switch gamificationViewModel.currentStreak {
        case 0:
            return .gray
        case 1...2:
            return .orange
        case 3...6:
            return .orange
        case 7...13:
            return .red
        case 14...29:
            return .red
        default:
            return .purple
        }
    }

    /// Status message based on streak
    private var streakStatusMessage: String {
        let streak = gamificationViewModel.currentStreak

        if streak == 0 {
            return "Start swiping to begin your streak!"
        } else if gamificationViewModel.hasActiveStreakToday {
            return "You're on fire! Keep it going tomorrow."
        } else {
            return "Don't lose your streak - swipe today!"
        }
    }

    /// Checks if a date had activity (simplified - would need DailyActivity data)
    private func isDateActive(_ date: Date) -> Bool {
        // For now, check if it's today and we have activity
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return gamificationViewModel.hasActiveStreakToday
        }

        // Check if within current streak
        let daysAgo = calendar.dateComponents([.day], from: date, to: Date()).day ?? 0
        return daysAgo < gamificationViewModel.currentStreak
    }
}

// MARK: - Streak Badge Component

/// Compact streak badge for use in other views
struct StreakBadge: View {

    let streakCount: Int
    let isActive: Bool

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill")
                .foregroundColor(isActive ? .orange : .gray)

            Text("\(streakCount)")
                .font(.subheadline.bold())
                .foregroundColor(isActive ? .black : .gray)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isActive ? Color.orange.opacity(0.1) : Color.gray.opacity(0.1))
        .cornerRadius(20)
    }
}

// MARK: - Previews

#Preview("Streak View") {
    NavigationStack {
        StreakView()
            .environmentObject(GamificationViewModel())
            .modelContainer(PersistenceController.preview.container)
    }
}

#Preview("Streak Badge - Active") {
    StreakBadge(streakCount: 7, isActive: true)
}

#Preview("Streak Badge - Inactive") {
    StreakBadge(streakCount: 0, isActive: false)
}
