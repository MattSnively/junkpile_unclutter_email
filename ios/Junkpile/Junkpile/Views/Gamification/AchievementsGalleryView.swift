import SwiftUI

/// AchievementsGalleryView displays all achievements organized by category.
/// Shows unlocked achievements with full color and locked ones grayed out.
struct AchievementsGalleryView: View {

    // MARK: - Environment

    @EnvironmentObject var gamificationViewModel: GamificationViewModel

    // MARK: - State

    /// Currently selected achievement for detail view
    @State private var selectedAchievement: Achievement?

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Progress summary
                progressSummary

                // Achievement categories
                ForEach(AchievementCategory.allCases) { category in
                    categorySection(category)
                }
            }
            .padding()
        }
        .background(Color(UIColor.systemGroupedBackground))
        .navigationTitle("Achievements")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedAchievement) { achievement in
            AchievementDetailView(
                achievement: achievement,
                isUnlocked: gamificationViewModel.isUnlocked(achievement),
                progress: gamificationViewModel.progress(for: achievement)
            )
        }
    }

    // MARK: - Components

    /// Progress summary at the top — combined as one VoiceOver element
    private var progressSummary: some View {
        HStack(spacing: 24) {
            // Unlocked count
            VStack(spacing: 4) {
                Text("\(gamificationViewModel.unlockedCount)")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.black)

                Text("Unlocked")
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            // Progress ring
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                    .frame(width: 80, height: 80)

                Circle()
                    .trim(from: 0, to: gamificationViewModel.achievementProgress)
                    .stroke(Color.black, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))

                Text("\(Int(gamificationViewModel.achievementProgress * 100))%")
                    .font(.headline)
                    .foregroundColor(.black)
            }

            // Total count
            VStack(spacing: 4) {
                Text("\(gamificationViewModel.totalAchievements)")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.gray)

                Text("Total")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(gamificationViewModel.unlockedCount) of \(gamificationViewModel.totalAchievements) achievements unlocked. \(Int(gamificationViewModel.achievementProgress * 100)) percent complete.")
    }

    /// Section for a single achievement category
    private func categorySection(_ category: AchievementCategory) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Category header
            Text(category.rawValue)
                .font(.headline)
                .foregroundColor(.black)
                .padding(.horizontal, 4)

            // Achievement grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(category.achievements) { achievement in
                    achievementCell(achievement)
                }
            }
        }
    }

    /// Single achievement cell in the grid — labeled with unlock status for VoiceOver
    private func achievementCell(_ achievement: Achievement) -> some View {
        let isUnlocked = gamificationViewModel.isUnlocked(achievement)

        return Button {
            selectedAchievement = achievement
        } label: {
            VStack(spacing: 8) {
                // Icon
                Image(systemName: achievement.iconName)
                    .font(.title)
                    .foregroundColor(isUnlocked ? .black : .gray.opacity(0.4))
                    .frame(width: 50, height: 50)
                    .background(isUnlocked ? Color.gray.opacity(0.1) : Color.gray.opacity(0.05))
                    .cornerRadius(12)

                // Title
                Text(achievement.title)
                    .font(.caption2)
                    .foregroundColor(isUnlocked ? .black : .gray)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isUnlocked ? Color.clear : Color.gray.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: isUnlocked ? .black.opacity(0.05) : .clear, radius: 5, x: 0, y: 2)
        }
        .accessibilityLabel("\(achievement.title). \(isUnlocked ? "Unlocked" : "Locked")")
        .accessibilityHint("Double tap to view details")
    }
}

// MARK: - Achievement Detail View

/// Detail view for a single achievement shown as a sheet.
/// Shows a progress bar for locked achievements that have a numeric threshold.
struct AchievementDetailView: View {

    let achievement: Achievement
    let isUnlocked: Bool

    /// Progress fraction (0.0–1.0) toward unlocking. Nil for session-behavior
    /// achievements where a progress bar doesn't apply.
    let progress: Double?

    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 24) {
            // Handle bar
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 40, height: 4)
                .padding(.top, 8)

            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(isUnlocked ? Color.black : Color.gray.opacity(0.2))
                    .frame(width: 100, height: 100)

                Image(systemName: achievement.iconName)
                    .font(.system(size: 44))
                    .foregroundColor(isUnlocked ? .white : .gray)
            }

            // Title
            Text(achievement.title)
                .font(.title2.bold())
                .foregroundColor(.black)

            // Status
            if isUnlocked {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Unlocked")
                        .foregroundColor(.green)
                }
                .font(.subheadline)
            } else {
                Text("Locked")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }

            // Description
            Text(achievement.description)
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            // Progress bar for locked achievements with a trackable threshold
            if !isUnlocked, let progress = progress, let threshold = achievement.threshold {
                VStack(spacing: 6) {
                    // Progress bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.2))

                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.black)
                                .frame(width: geometry.size.width * progress)
                        }
                    }
                    .frame(height: 8)
                    .accessibilityHidden(true)

                    // Progress label — e.g., "3 / 10"
                    Text("\(Int(progress * Double(threshold))) / \(threshold)")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 32)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(Int(progress * 100)) percent progress toward \(achievement.title)")
            }

            // Bonus points
            VStack(spacing: 4) {
                Text("+\(achievement.pointsBonus)")
                    .font(.title3.bold())
                    .foregroundColor(isUnlocked ? .black : .gray)

                Text("Bonus Points")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 32)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)

            Spacer()

            // Dismiss button
            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.black)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Achievement Unlock Animation View

/// Animated overlay shown when an achievement is unlocked.
/// Respects Reduce Motion — uses simple opacity fade instead of spring scale.
struct AchievementUnlockView: View {

    let achievement: Achievement
    let onDismiss: () -> Void

    @State private var showContent = false
    @State private var showConfetti = false

    /// Respects the user's Reduce Motion preference
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        ZStack {
            // Background
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel("Dismiss achievement")

            // Content
            VStack(spacing: 24) {
                // Badge animation — scale effect only when Reduce Motion is off
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 120, height: 120)
                        .scaleEffect(reduceMotion ? 1 : (showContent ? 1 : 0))
                        .opacity(showContent ? 1 : 0)

                    Image(systemName: achievement.iconName)
                        .font(.system(size: 50))
                        .foregroundColor(.black)
                        .scaleEffect(reduceMotion ? 1 : (showContent ? 1 : 0))
                        .opacity(showContent ? 1 : 0)
                }

                // Title
                Text("Achievement Unlocked!")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                    .opacity(showContent ? 1 : 0)

                Text(achievement.title)
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.8))
                    .opacity(showContent ? 1 : 0)

                // Bonus
                Text("+\(achievement.pointsBonus) pts")
                    .font(.title3.bold())
                    .foregroundColor(.yellow)
                    .opacity(showContent ? 1 : 0)

                // Explicit dismiss button — lets user acknowledge at their own pace
                Button {
                    onDismiss()
                } label: {
                    Text("Awesome!")
                        .font(.headline)
                        .foregroundColor(.black)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .background(Color.white)
                        .cornerRadius(24)
                }
                .opacity(showContent ? 1 : 0)
                .accessibilityLabel("Dismiss achievement")
            }
            // Use simple opacity when Reduce Motion is on, spring when off
            .animation(reduceMotion
                ? .easeInOut(duration: 0.3)
                : .spring(response: 0.6, dampingFraction: 0.7),
                value: showContent
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Achievement unlocked: \(achievement.title). Plus \(achievement.pointsBonus) bonus points. Double tap to dismiss.")
            .accessibilityAddTraits(.isButton)
        }
        .onAppear {
            withAnimation {
                showContent = true
            }

            // Celebratory haptic for achievement unlock
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        }
        // 8-second safety-net auto-dismiss — cancellable if user taps "Awesome!"
        // or the background first. Uses structured concurrency instead of
        // DispatchQueue so the timer is automatically cancelled on view removal.
        .task {
            try? await Task.sleep(for: .seconds(8))
            onDismiss()
        }
    }
}

// MARK: - Previews

#Preview("Achievements Gallery") {
    NavigationStack {
        AchievementsGalleryView()
            .environmentObject(GamificationViewModel())
            .modelContainer(PersistenceController.preview.container)
    }
}

#Preview("Achievement Detail - Unlocked") {
    AchievementDetailView(achievement: .emailAssassin, isUnlocked: true, progress: 1.0)
}

#Preview("Achievement Detail - Locked") {
    AchievementDetailView(achievement: .inboxGrandmaster, isUnlocked: false, progress: 0.35)
}

#Preview("Achievement Detail - Locked No Progress") {
    AchievementDetailView(achievement: .noMercy, isUnlocked: false, progress: nil)
}

#Preview("Achievement Unlock Animation") {
    AchievementUnlockView(achievement: .weekWarrior) {}
}
