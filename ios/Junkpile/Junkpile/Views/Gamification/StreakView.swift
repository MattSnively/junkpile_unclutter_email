import SwiftUI
import SwiftData

/// StreakView displays the user's current and longest streaks with visual indicators.
struct StreakView: View {

    // MARK: - Environment

    @EnvironmentObject var gamificationViewModel: GamificationViewModel

    /// Model context for querying actual DailyActivity records
    @Environment(\.modelContext) private var modelContext

    /// Respects the user's Reduce Motion accessibility setting.
    /// When enabled, disables the flame pulse animation.
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    // MARK: - State

    /// Drives the flame icon pulse animation when the user has an active streak.
    @State private var isPulsing = false

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

    /// Large current streak display — combined as one VoiceOver element
    private var currentStreakCard: some View {
        VStack(spacing: 16) {
            // Flame icon with pulse animation — pulses when streak is active,
            // static when streak is zero or Reduce Motion is enabled
            ZStack {
                Circle()
                    .fill(streakColor.opacity(0.1))
                    .frame(width: 100, height: 100)

                Image(systemName: "flame.fill")
                    .font(.system(size: 50))
                    .foregroundColor(streakColor)
            }
            .scaleEffect(isPulsing ? 1.08 : 1.0)
            .onAppear {
                // Only animate when the user has an active streak and hasn't
                // enabled Reduce Motion — prevents distracting motion
                if gamificationViewModel.currentStreak > 0 && !reduceMotion {
                    withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                        isPulsing = true
                    }
                }
            }

            // Streak count
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text("\(gamificationViewModel.currentStreak.localized)")
                    .font(.system(size: 60, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                Text(gamificationViewModel.currentStreak == 1 ? "day" : "days")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }

            // Status message
            Text(streakStatusMessage)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity)
        .background(Theme.cardBackground)
        .cornerRadius(20)
        .shadow(color: Theme.shadow(opacity: 0.05), radius: 10, x: 0, y: 5)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Current streak: \(gamificationViewModel.currentStreak) \(gamificationViewModel.currentStreak == 1 ? "day" : "days"). \(streakStatusMessage)")
    }

    /// Weekly activity visualization (last 7 days)
    private var weeklyActivityView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("This Week")
                .font(.headline)
                .foregroundColor(.primary)

            HStack(spacing: 8) {
                ForEach(0..<7, id: \.self) { dayOffset in
                    dayCircle(for: dayOffset)
                }
            }
        }
        .padding(16)
        .background(Theme.cardBackground)
        .cornerRadius(16)
        .shadow(color: Theme.shadow(opacity: 0.05), radius: 5, x: 0, y: 2)
    }

    /// Single day circle in the weekly view — each day readable by VoiceOver
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
                    .fill(isActive ? Color.orange : Theme.subtleFill)
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
                .foregroundColor(isToday ? .primary : .secondary)
                .fontWeight(isToday ? .bold : .regular)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(dayName)\(isToday ? ", today" : ""). \(isActive ? "Active" : "Inactive")")
    }

    /// Row showing streak statistics — each stat is a combined VoiceOver element
    private var streakStatsRow: some View {
        HStack(spacing: 24) {
            // Longest streak
            VStack(spacing: 8) {
                Image(systemName: "trophy.fill")
                    .font(.title2)
                    .foregroundColor(.yellow)

                Text("\(gamificationViewModel.longestStreak.localized)")
                    .font(.title2.bold())
                    .foregroundColor(.primary)

                Text("Longest Streak")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(Theme.cardBackground)
            .cornerRadius(12)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Longest streak: \(gamificationViewModel.longestStreak) days")

            // Total active days
            VStack(spacing: 8) {
                Image(systemName: "calendar.badge.checkmark")
                    .font(.title2)
                    .foregroundColor(.green)

                Text("\(gamificationViewModel.totalSessions.localized)")
                    .font(.title2.bold())
                    .foregroundColor(.primary)

                Text("Total Sessions")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(Theme.cardBackground)
            .cornerRadius(12)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Total sessions: \(gamificationViewModel.totalSessions)")
        }
        .shadow(color: Theme.shadow(opacity: 0.05), radius: 5, x: 0, y: 2)
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

    /// Checks if a date had actual activity by querying the DailyActivity SwiftData model.
    /// Replaces the previous streak-based heuristic that showed false positives for
    /// non-consecutive days within the streak count.
    private func isDateActive(_ date: Date) -> Bool {
        let startOfDay = Calendar.current.startOfDay(for: date)
        let descriptor = FetchDescriptor<DailyActivity>(
            predicate: #Predicate { $0.date == startOfDay && $0.countsTowardStreak == true }
        )
        let results = (try? modelContext.fetch(descriptor)) ?? []
        return !results.isEmpty
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

            Text("\(streakCount.localized)")
                .font(.subheadline.bold())
                .foregroundColor(isActive ? .primary : .secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isActive ? Color.orange.opacity(0.1) : Theme.subtleFill)
        .cornerRadius(20)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(streakCount) day streak\(isActive ? ", active" : "")")
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
