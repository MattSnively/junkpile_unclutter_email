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
                    .fill(Theme.solidFill)
                    .frame(width: 80, height: 80)

                Text(gamificationViewModel.profile?.displayName.prefix(1).uppercased() ?? "?")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(Theme.solidFillForeground)
            }

            // Name
            Text(gamificationViewModel.profile?.displayName ?? "User")
                .font(.title2.bold())
                .foregroundColor(.primary)

            // Level title
            Text(gamificationViewModel.levelTitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
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
                        .foregroundColor(.secondary)

                    Text("\(gamificationViewModel.currentLevel.localized)")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.primary)
                }

                Spacer()

                // XP count
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Total XP")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(gamificationViewModel.formattedXP)
                        .font(.title3.bold())
                        .foregroundColor(.primary)
                }
            }

            // Progress bar
            VStack(spacing: 8) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Theme.subtleFillStrong)

                        // Progress
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Theme.solidFill)
                            .frame(width: geometry.size.width * gamificationViewModel.levelProgress)
                    }
                }
                .frame(height: 12)
                .accessibilityHidden(true)

                // XP to next level
                HStack {
                    Text("\(gamificationViewModel.xpToNextLevel.localized) XP to Level \(gamificationViewModel.currentLevel + 1)")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    Text("\(Int(gamificationViewModel.levelProgress * 100))%")
                        .font(.caption.bold())
                        .foregroundColor(.primary)
                }
            }
        }
        .padding(20)
        .background(Theme.cardBackground)
        .cornerRadius(16)
        .shadow(color: Theme.shadow(opacity: 0.05), radius: 10, x: 0, y: 2)
        // Combine into one VoiceOver element for level progress
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Level \(gamificationViewModel.currentLevel). \(gamificationViewModel.formattedXP) total XP. \(Int(gamificationViewModel.levelProgress * 100)) percent to level \(gamificationViewModel.currentLevel + 1). \(gamificationViewModel.xpToNextLevel) XP remaining.")
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
                value: "\(gamificationViewModel.currentStreak.localized) days",
                icon: "flame.fill",
                color: .orange
            )

            statCard(
                title: "Unsubscribed",
                value: "\(gamificationViewModel.lifetimeUnsubscribes.localized)",
                icon: "xmark.circle.fill",
                color: .red
            )

            statCard(
                title: "Kept",
                value: "\(gamificationViewModel.lifetimeKeeps.localized)",
                icon: "checkmark.circle.fill",
                color: .green
            )
        }
    }

    /// Single stat card component — combined as one VoiceOver element
    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(value)
                .font(.headline)
                .foregroundColor(.primary)
                .minimumScaleFactor(0.7)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Theme.cardBackground)
        .cornerRadius(12)
        .shadow(color: Theme.shadow(opacity: 0.05), radius: 5, x: 0, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }

    /// Quick preview of achievements with navigation link
    private var achievementsPreview: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Achievements")
                    .font(.headline)
                    .foregroundColor(.primary)

                Spacer()

                NavigationLink(destination: AchievementsGalleryView()) {
                    HStack(spacing: 4) {
                        Text("View All")
                            .font(.subheadline)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
            }

            // Achievement progress bar
            VStack(spacing: 8) {
                HStack {
                    Text("\(gamificationViewModel.unlockedCount.localized) of \(gamificationViewModel.totalAchievements.localized)")
                        .font(.subheadline)
                        .foregroundColor(.primary)

                    Spacer()

                    Text("\(Int(gamificationViewModel.achievementProgress * 100))%")
                        .font(.subheadline.bold())
                        .foregroundColor(.primary)
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Theme.subtleFillStrong)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(Theme.solidFill)
                            .frame(width: geometry.size.width * gamificationViewModel.achievementProgress)
                    }
                }
                .frame(height: 8)
                .accessibilityHidden(true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(gamificationViewModel.unlockedCount) of \(gamificationViewModel.totalAchievements) achievements unlocked. \(Int(gamificationViewModel.achievementProgress * 100)) percent.")

            // Recent achievements
            HStack(spacing: 12) {
                ForEach(gamificationViewModel.unlockedAchievements.prefix(5)) { unlocked in
                    if let achievement = unlocked.achievement {
                        Image(systemName: achievement.iconName)
                            .font(.title2)
                            .foregroundColor(.primary)
                            .frame(width: 44, height: 44)
                            .background(Theme.subtleFill)
                            .cornerRadius(8)
                    }
                }

                Spacer()
            }
        }
        .padding(16)
        .background(Theme.cardBackground)
        .cornerRadius(16)
        .shadow(color: Theme.shadow(opacity: 0.05), radius: 10, x: 0, y: 2)
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

#Preview("Profile View - Dark") {
    NavigationStack {
        ProfileView()
            .environmentObject(GamificationViewModel())
            .modelContainer(PersistenceController.preview.container)
    }
    .preferredColorScheme(.dark)
}
