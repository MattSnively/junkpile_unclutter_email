import SwiftUI
import SwiftData

/// HomeView is the main dashboard showing stats, streak, level progress, and quick actions.
struct HomeView: View {

    // MARK: - Environment

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var gamificationViewModel: GamificationViewModel

    // MARK: - State

    /// Whether achievement unlock overlay is shown
    @State private var showingAchievementUnlock = false
    @State private var pendingAchievement: Achievement?

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Welcome header
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
                            .foregroundColor(.black)
                    }
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
                Text("Welcome back,")
                    .font(.subheadline)
                    .foregroundColor(.gray)

                Text(authViewModel.displayName)
                    .font(.title2.bold())
                    .foregroundColor(.black)
            }

            Spacer()

            // Points badge
            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)

                Text(gamificationViewModel.formattedPoints)
                    .font(.subheadline.bold())
                    .foregroundColor(.black)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.yellow.opacity(0.1))
            .cornerRadius(20)
        }
    }

    /// Streak display card
    private var streakCard: some View {
        NavigationLink(destination: StreakView()) {
            HStack(spacing: 16) {
                // Flame icon
                ZStack {
                    Circle()
                        .fill(gamificationViewModel.currentStreak > 0 ? Color.orange.opacity(0.1) : Color.gray.opacity(0.1))
                        .frame(width: 60, height: 60)

                    Image(systemName: "flame.fill")
                        .font(.title)
                        .foregroundColor(gamificationViewModel.currentStreak > 0 ? .orange : .gray)
                }

                // Streak info
                VStack(alignment: .leading, spacing: 4) {
                    Text(gamificationViewModel.streakStatus)
                        .font(.headline)
                        .foregroundColor(.black)

                    Text(gamificationViewModel.hasActiveStreakToday ? "Streak active today" : "Swipe to keep your streak!")
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
            .padding(16)
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
    }

    /// Level progress card
    private var levelProgressCard: some View {
        VStack(spacing: 12) {
            HStack {
                // Level badge
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(Color.black)
                            .frame(width: 40, height: 40)

                        Text("\(gamificationViewModel.currentLevel)")
                            .font(.headline.bold())
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Level \(gamificationViewModel.currentLevel)")
                            .font(.headline)
                            .foregroundColor(.black)

                        Text(gamificationViewModel.levelTitle)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }

                Spacer()

                // XP display
                Text(gamificationViewModel.formattedXP)
                    .font(.subheadline.bold())
                    .foregroundColor(.black)
            }

            // Progress bar
            VStack(spacing: 4) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))

                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.black)
                            .frame(width: geometry.size.width * gamificationViewModel.levelProgress)
                    }
                }
                .frame(height: 8)

                HStack {
                    Text("\(gamificationViewModel.xpToNextLevel) XP to next level")
                        .font(.caption)
                        .foregroundColor(.gray)

                    Spacer()
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }

    /// Quick stats row
    private var quickStatsRow: some View {
        HStack(spacing: 12) {
            // Unsubscribed
            statBox(
                value: "\(gamificationViewModel.lifetimeUnsubscribes)",
                label: "Unsubscribed",
                icon: "xmark.circle.fill",
                color: .red
            )

            // Kept
            statBox(
                value: "\(gamificationViewModel.lifetimeKeeps)",
                label: "Kept",
                icon: "checkmark.circle.fill",
                color: .green
            )

            // Sessions
            statBox(
                value: "\(gamificationViewModel.totalSessions)",
                label: "Sessions",
                icon: "repeat",
                color: .blue
            )
        }
    }

    /// Single stat box
    private func statBox(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(value)
                .font(.title3.bold())
                .foregroundColor(.black)

            Text(label)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }

    /// Quick action card to start swiping
    private var quickActionCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "hand.draw.fill")
                .font(.largeTitle)
                .foregroundColor(.black)

            Text("Ready to clean your inbox?")
                .font(.headline)
                .foregroundColor(.black)

            Text("Swipe through emails with unsubscribe options")
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [Color.gray.opacity(0.05), Color.gray.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.black, lineWidth: 2)
        )
    }

    /// Recent achievements preview
    private var recentAchievementsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Achievements")
                    .font(.headline)
                    .foregroundColor(.black)

                Spacer()

                NavigationLink(destination: AchievementsGalleryView()) {
                    Text("View All")
                        .font(.caption)
                        .foregroundColor(.gray)
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
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }

    /// Small achievement badge
    private func achievementBadge(_ achievement: Achievement) -> some View {
        VStack(spacing: 6) {
            Image(systemName: achievement.iconName)
                .font(.title2)
                .foregroundColor(.black)
                .frame(width: 50, height: 50)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)

            Text(achievement.title)
                .font(.caption2)
                .foregroundColor(.gray)
                .lineLimit(1)
        }
        .frame(width: 70)
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
    authVM.isAuthenticated = true

    return HomeView()
        .environmentObject(authVM)
        .environmentObject(GamificationViewModel())
        .modelContainer(PersistenceController.preview.container)
}
