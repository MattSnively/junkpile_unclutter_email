import SwiftUI
import SwiftData

/// HomeView is the main dashboard showing stats, streak, level progress, and quick actions.
struct HomeView: View {

    // MARK: - Environment

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var gamificationViewModel: GamificationViewModel

    // MARK: - Navigation

    /// Binding to the tab bar's selected tab, used to navigate to Swipe tab from quick action card
    @Binding var selectedTab: Tab

    // MARK: - State

    /// Whether achievement unlock overlay is shown
    @State private var showingAchievementUnlock = false
    @State private var pendingAchievement: Achievement?

    /// Drives the flame icon pulse animation on the streak card
    @State private var isStreakPulsing = false

    /// Respects the user's Reduce Motion accessibility setting
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if gamificationViewModel.totalSessions == 0 {
                        // Empty state — user hasn't completed any sessions yet.
                        // Show a welcoming hero card instead of empty stats.
                        welcomeHeader
                        firstSessionHeroCard
                    } else {
                        // Normal dashboard with stats, streak, and level
                        welcomeHeader

                        // Streak card
                        streakCard

                        // Level progress card
                        levelProgressCard

                        // Quick stats row
                        quickStatsRow

                        // Quick action button
                        quickActionCard

                        // Recent achievements
                        if !gamificationViewModel.unlockedAchievements.isEmpty {
                            recentAchievementsCard
                        }
                    }
                }
                .padding()
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Junkpile")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: ProfileView()) {
                        Image(systemName: "person.circle")
                            .font(.title2)
                            .foregroundColor(.primary)
                    }
                    .accessibilityLabel("Profile")
                    .accessibilityHint("View your profile and statistics")
                }
            }
            .onAppear {
                gamificationViewModel.configure(with: modelContext)
                checkForUnseenAchievements()
            }
            .overlay {
                if showingAchievementUnlock, let achievement = pendingAchievement {
                    AchievementUnlockView(achievement: achievement) {
                        gamificationViewModel.markAchievementSeen(achievement)
                        showingAchievementUnlock = false
                        pendingAchievement = nil
                        checkForUnseenAchievements()
                    }
                    .transition(.opacity)
                }
            }
        }
    }

    // MARK: - Components

    /// Welcome header with user greeting
    private var welcomeHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                // Show "Welcome," for first-time users, "Welcome back," for returning users
                Text(gamificationViewModel.totalSessions == 0 ? "Welcome," : "Welcome back,")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text(authViewModel.displayName)
                    .font(.title2.bold())
                    .foregroundColor(.primary)
            }

            Spacer()

            // Points badge — combined for VoiceOver
            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)

                Text(gamificationViewModel.formattedPoints)
                    .font(.subheadline.bold())
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.yellow.opacity(0.1))
            .cornerRadius(20)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(gamificationViewModel.formattedPoints) points")
        }
    }

    /// Streak display card
    private var streakCard: some View {
        NavigationLink(destination: StreakView()) {
            HStack(spacing: 16) {
                // Flame icon — pulses when streak is active,
                // static when streak is zero or Reduce Motion is enabled
                ZStack {
                    Circle()
                        .fill(gamificationViewModel.currentStreak > 0 ? Color.orange.opacity(0.1) : Theme.subtleFill)
                        .frame(width: 60, height: 60)

                    Image(systemName: "flame.fill")
                        .font(.title)
                        .foregroundColor(gamificationViewModel.currentStreak > 0 ? .orange : .gray)
                }
                .scaleEffect(isStreakPulsing ? 1.08 : 1.0)
                .onAppear {
                    if gamificationViewModel.currentStreak > 0 && !reduceMotion {
                        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                            isStreakPulsing = true
                        }
                    }
                }

                // Streak info
                VStack(alignment: .leading, spacing: 4) {
                    Text(gamificationViewModel.streakStatus)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(gamificationViewModel.hasActiveStreakToday ? "Streak active today" : "Swipe to keep your streak!")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .accessibilityHidden(true)
            }
            .padding(16)
            .background(Theme.cardBackground)
            .cornerRadius(16)
            .shadow(color: Theme.shadow(opacity: 0.05), radius: 5, x: 0, y: 2)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(gamificationViewModel.streakStatus). \(gamificationViewModel.hasActiveStreakToday ? "Streak active today" : "Swipe to keep your streak")")
        .accessibilityHint("Double tap to view streak details")
    }

    /// Level progress card
    private var levelProgressCard: some View {
        VStack(spacing: 12) {
            HStack {
                // Level badge
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(Theme.solidFill)
                            .frame(width: 40, height: 40)

                        Text("\(gamificationViewModel.currentLevel.localized)")
                            .font(.headline.bold())
                            .foregroundColor(Theme.solidFillForeground)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Level \(gamificationViewModel.currentLevel.localized)")
                            .font(.headline)
                            .foregroundColor(.primary)

                        Text(gamificationViewModel.levelTitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // XP display
                Text(gamificationViewModel.formattedXP)
                    .font(.subheadline.bold())
                    .foregroundColor(.primary)
            }

            // Progress bar
            VStack(spacing: 4) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Theme.subtleFillStrong)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(Theme.solidFill)
                            .frame(width: geometry.size.width * gamificationViewModel.levelProgress)
                    }
                }
                .frame(height: 8)
                .accessibilityHidden(true)

                HStack {
                    Text("\(gamificationViewModel.xpToNextLevel.localized) XP to next level")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()
                }
            }
        }
        .padding(16)
        .background(Theme.cardBackground)
        .cornerRadius(16)
        .shadow(color: Theme.shadow(opacity: 0.05), radius: 5, x: 0, y: 2)
        // Combine entire card into one VoiceOver element
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Level \(gamificationViewModel.currentLevel), \(gamificationViewModel.levelTitle). \(gamificationViewModel.formattedXP). \(gamificationViewModel.xpToNextLevel) XP to next level. \(Int(gamificationViewModel.levelProgress * 100)) percent progress.")
    }

    /// Quick stats row
    private var quickStatsRow: some View {
        HStack(spacing: 12) {
            // Unsubscribed
            statBox(
                value: "\(gamificationViewModel.lifetimeUnsubscribes.localized)",
                label: "Unsubscribed",
                icon: "xmark.circle.fill",
                color: .red
            )

            // Kept
            statBox(
                value: "\(gamificationViewModel.lifetimeKeeps.localized)",
                label: "Kept",
                icon: "checkmark.circle.fill",
                color: .green
            )

            // Sessions
            statBox(
                value: "\(gamificationViewModel.totalSessions.localized)",
                label: "Sessions",
                icon: "repeat",
                color: .blue
            )
        }
    }

    /// Single stat box — combined as one VoiceOver element (e.g., "42 Unsubscribed")
    private func statBox(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(value)
                .font(.title3.bold())
                .foregroundColor(.primary)
                .minimumScaleFactor(0.7)

            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Theme.cardBackground)
        .cornerRadius(12)
        .shadow(color: Theme.shadow(opacity: 0.05), radius: 5, x: 0, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value) \(label)")
    }

    /// Hero card shown when the user has zero sessions.
    /// Provides a welcoming introduction and encourages the first swipe session.
    private var firstSessionHeroCard: some View {
        VStack(spacing: 20) {
            // Large app icon / illustration
            ZStack {
                Circle()
                    .fill(Theme.illustrationCircle)
                    .frame(width: 120, height: 120)

                Image(systemName: "hand.draw.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.primary)
            }

            // Headline
            Text("Start Your First Session")
                .font(.title2.bold())
                .foregroundColor(.primary)

            // Description
            Text("Swipe through your emails to unsubscribe from newsletters you no longer read. Earn points, level up, and build a streak!")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)

            // How it works
            VStack(alignment: .leading, spacing: 12) {
                howItWorksRow(icon: "arrow.right.circle.fill", color: .green, text: "Swipe right to keep")
                howItWorksRow(icon: "arrow.left.circle.fill", color: .red, text: "Swipe left to unsubscribe")
                howItWorksRow(icon: "star.fill", color: .yellow, text: "Earn points with every decision")
            }
            .padding(.vertical, 8)
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .background(Theme.cardBackground)
        .cornerRadius(20)
        .shadow(color: Theme.shadow(opacity: 0.08), radius: 10, x: 0, y: 5)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Start your first session. Swipe right to keep emails, swipe left to unsubscribe. Earn points with every decision.")
    }

    /// Single row in the "how it works" section of the hero card
    private func howItWorksRow(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 30)

            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
        }
    }

    /// Quick action card to start swiping — tapping navigates to the Swipe tab
    private var quickActionCard: some View {
        Button {
            selectedTab = .swipe
        } label: {
            VStack(spacing: 12) {
                Image(systemName: "hand.draw.fill")
                    .font(.largeTitle)
                    .foregroundColor(.primary)

                Text("Ready to clean your inbox?")
                    .font(.headline)
                    .foregroundColor(.primary)

                Text("Swipe through emails with unsubscribe options")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    colors: [Theme.subtleFill.opacity(0.5), Theme.subtleFill],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Theme.cardBorder, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Start swiping emails")
        .accessibilityHint("Switches to the Swipe tab to begin cleaning your inbox")
    }

    /// Recent achievements preview
    private var recentAchievementsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Achievements")
                    .font(.headline)
                    .foregroundColor(.primary)

                Spacer()

                NavigationLink(destination: AchievementsGalleryView()) {
                    Text("View All")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(gamificationViewModel.unlockedAchievements.prefix(5)) { unlocked in
                        if let achievement = unlocked.achievement {
                            achievementBadge(achievement)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Theme.cardBackground)
        .cornerRadius(16)
        .shadow(color: Theme.shadow(opacity: 0.05), radius: 5, x: 0, y: 2)
    }

    /// Small achievement badge — combined for VoiceOver
    private func achievementBadge(_ achievement: Achievement) -> some View {
        VStack(spacing: 6) {
            Image(systemName: achievement.iconName)
                .font(.title2)
                .foregroundColor(.primary)
                .frame(width: 50, height: 50)
                .background(Theme.subtleFill)
                .cornerRadius(12)

            Text(achievement.title)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(width: 70)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Achievement: \(achievement.title)")
    }

    // MARK: - Methods

    /// Checks for unseen achievements and shows unlock animation
    private func checkForUnseenAchievements() {
        if let achievement = gamificationViewModel.unseenAchievements.first {
            pendingAchievement = achievement
            withAnimation {
                showingAchievementUnlock = true
            }
        }
    }
}

// MARK: - Previews

#Preview("Home View") {
    let authVM = AuthViewModel()
    authVM.authState = .authenticated

    return HomeView(selectedTab: .constant(.home))
        .environmentObject(authVM)
        .environmentObject(GamificationViewModel())
        .modelContainer(PersistenceController.preview.container)
}

#Preview("Home View - Dark") {
    let authVM = AuthViewModel()
    authVM.authState = .authenticated

    return HomeView(selectedTab: .constant(.home))
        .environmentObject(authVM)
        .environmentObject(GamificationViewModel())
        .modelContainer(PersistenceController.preview.container)
        .preferredColorScheme(.dark)
}
