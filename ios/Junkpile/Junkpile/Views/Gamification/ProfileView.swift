import SwiftUI
import SwiftData

/// ProfileView displays the user's gamification profile including level, XP, and stats.
struct ProfileView: View {

    // MARK: - Environment

    @EnvironmentObject var gamificationViewModel: GamificationViewModel

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Profile header with avatar and level
                profileHeader

                // Level progress card
                levelProgressCard

                // Stats grid
                statsGrid

                // Quick achievements preview
                achievementsPreview
            }
            .padding()
        }
        .background(Color(UIColor.systemGroupedBackground))
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Components

    /// Profile header with avatar, name, and title
    private var profileHeader: some View {
        VStack(spacing: 12) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Color.black)
                    .frame(width: 80, height: 80)

                Text(gamificationViewModel.profile?.displayName.prefix(1).uppercased() ?? "?")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
            }

            // Name
            Text(gamificationViewModel.profile?.displayName ?? "User")
                .font(.title2.bold())
                .foregroundColor(.black)

            // Level title
            Text(gamificationViewModel.levelTitle)
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .padding(.vertical, 16)
    }

    /// Level progress card showing XP and progress to next level
    private var levelProgressCard: some View {
        VStack(spacing: 16) {
            // Level badge
            HStack {
                // Current level
                VStack(alignment: .leading, spacing: 4) {
                    Text("Level")
                        .font(.caption)
                        .foregroundColor(.gray)

                    Text("\(gamificationViewModel.currentLevel)")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.black)
                }

                Spacer()

                // XP count
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Total XP")
                        .font(.caption)
                        .foregroundColor(.gray)

                    Text(gamificationViewModel.formattedXP)
                        .font(.title3.bold())
                        .foregroundColor(.black)
                }
            }

            // Progress bar
            VStack(spacing: 8) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.gray.opacity(0.2))

                        // Progress
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.black)
                            .frame(width: geometry.size.width * gamificationViewModel.levelProgress)
                    }
                }
                .frame(height: 12)

                // XP to next level
                HStack {
                    Text("\(gamificationViewModel.xpToNextLevel) XP to Level \(gamificationViewModel.currentLevel + 1)")
                        .font(.caption)
                        .foregroundColor(.gray)

                    Spacer()

                    Text("\(Int(gamificationViewModel.levelProgress * 100))%")
                        .font(.caption.bold())
                        .foregroundColor(.black)
                }
            }
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 2)
    }

    /// Grid of key statistics
    private var statsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            statCard(
                title: "Points",
                value: gamificationViewModel.formattedPoints,
                icon: "star.fill",
                color: .yellow
            )

            statCard(
                title: "Current Streak",
                value: "\(gamificationViewModel.currentStreak) days",
                icon: "flame.fill",
                color: .orange
            )

            statCard(
                title: "Unsubscribed",
                value: "\(gamificationViewModel.lifetimeUnsubscribes)",
                icon: "xmark.circle.fill",
                color: .red
            )

            statCard(
                title: "Kept",
                value: "\(gamificationViewModel.lifetimeKeeps)",
                icon: "checkmark.circle.fill",
                color: .green
            )
        }
    }

    /// Single stat card component
    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(value)
                .font(.headline)
                .foregroundColor(.black)

            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }

    /// Quick preview of achievements with navigation link
    private var achievementsPreview: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Achievements")
                    .font(.headline)
                    .foregroundColor(.black)

                Spacer()

                NavigationLink(destination: AchievementsGalleryView()) {
                    HStack(spacing: 4) {
                        Text("View All")
                            .font(.subheadline)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                    }
                    .foregroundColor(.gray)
                }
            }

            // Achievement progress bar
            VStack(spacing: 8) {
                HStack {
                    Text("\(gamificationViewModel.unlockedCount) of \(gamificationViewModel.totalAchievements)")
                        .font(.subheadline)
                        .foregroundColor(.black)

                    Spacer()

                    Text("\(Int(gamificationViewModel.achievementProgress * 100))%")
                        .font(.subheadline.bold())
                        .foregroundColor(.black)
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))

                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.black)
                            .frame(width: geometry.size.width * gamificationViewModel.achievementProgress)
                    }
                }
                .frame(height: 8)
            }

            // Recent achievements
            HStack(spacing: 12) {
                ForEach(gamificationViewModel.unlockedAchievements.prefix(5)) { unlocked in
                    if let achievement = unlocked.achievement {
                        Image(systemName: achievement.iconName)
                            .font(.title2)
                            .foregroundColor(.black)
                            .frame(width: 44, height: 44)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }
                }

                Spacer()
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 2)
    }
}

// MARK: - Previews

#Preview("Profile View") {
    NavigationStack {
        ProfileView()
            .environmentObject(GamificationViewModel())
            .modelContainer(PersistenceController.preview.container)
    }
}
