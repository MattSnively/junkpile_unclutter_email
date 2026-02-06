import SwiftUI
import SwiftData

/// SwipeContainerView is the main container for the swipe session experience.
/// Handles the different session states: not started, loading, swiping, and complete.
struct SwipeContainerView: View {

    // MARK: - Environment

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var gamificationViewModel: GamificationViewModel

    // MARK: - Bindings

    /// Binding to the parent tab selection — allows SessionCompleteView
    /// to navigate the user to Stats or Home after finishing a session.
    @Binding var selectedTab: Tab

    // MARK: - State

    @StateObject private var viewModel = SwipeViewModel()

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.sessionState {
                case .notStarted:
                    SessionStartView(onStart: startSession)

                case .loading:
                    SkeletonLoadingView()

                case .swiping:
                    SwipeView(viewModel: viewModel)

                case .completed:
                    SessionCompleteView(
                        viewModel: viewModel,
                        selectedTab: $selectedTab,
                        onNewSession: { viewModel.resetSession() }
                    )

                case .error(let userError):
                    ErrorView(error: userError, onRetry: startSession)
                }
            }
            // Undo button overlay — floats above all session states so it
            // persists even when the session transitions to .completed after
            // the last card is swiped. Appears with animation when a pending
            // decision exists, disappears when the undo window expires.
            .overlay(alignment: .bottom) {
                if viewModel.pendingDecision != nil {
                    UndoButton(
                        timeRemaining: viewModel.undoTimeRemaining,
                        onUndo: { viewModel.undoLastDecision() }
                    )
                    .padding(.bottom, 32)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: viewModel.pendingDecision != nil)
            .navigationTitle("Swipe")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                viewModel.configure(with: modelContext)
            }
            // Commit any pending decision when the user navigates away
            // (e.g., switching tabs). Prevents stale undo state and ensures
            // the API call fires even if the timer hasn't expired.
            .onDisappear {
                viewModel.commitIfPending()
            }
        }
    }

    // MARK: - Actions

    /// Starts a new swipe session
    private func startSession() {
        Task {
            await viewModel.startSession()
        }
    }
}

// MARK: - Session Start View

/// View shown before a session begins with a start button
struct SessionStartView: View {

    let onStart: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Icon
            Image(systemName: "envelope.badge.fill")
                .font(.system(size: 80))
                .foregroundStyle(.black, .red)

            // Title
            Text("Ready to Clean?")
                .font(.title.bold())
                .foregroundColor(.black)

            // Description
            Text("We'll fetch your emails with unsubscribe options.\nSwipe left to unsubscribe, right to keep.")
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            // Start button
            Button(action: onStart) {
                Text("Start Session")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.black)
                    .cornerRadius(12)
            }
            .accessibilityLabel("Start Session")
            .accessibilityHint("Fetches emails with unsubscribe options for you to review")
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }
}

// MARK: - Loading View

/// View shown while emails are being fetched
struct LoadingView: View {

    var body: some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.black)
                .accessibilityLabel("Loading emails")

            Text("Fetching your emails...")
                .font(.headline)
                .foregroundColor(.gray)
        }
    }
}

// MARK: - Swipe View

/// Main swipe interface with card stack and progress tracking
struct SwipeView: View {

    @ObservedObject var viewModel: SwipeViewModel

    /// Persists across sessions — once the user has swiped 3 cards,
    /// they understand the mechanic and hints stay hidden permanently.
    @AppStorage("hasSeenSwipeHints") private var hasSeenSwipeHints = false

    var body: some View {
        VStack(spacing: 0) {
            // Progress bar
            progressBar
                .padding(.horizontal, 20)
                .padding(.top, 8)

            // Stats row
            statsRow
                .padding(.horizontal, 20)
                .padding(.top, 12)

            // Card stack
            EmailCardStack(
                emails: viewModel.emails,
                currentIndex: $viewModel.currentIndex
            ) { email, action in
                viewModel.recordDecision(email: email, action: action)
            }
            .padding(.vertical, 20)

            // Swipe hints — hidden after user has swiped 3 cards
            if !hasSeenSwipeHints {
                swipeHints
                    .padding(.bottom, 20)
            }
        }
        // Hide hints after the user swipes their 3rd card (index becomes 3)
        .onChange(of: viewModel.currentIndex) { _, newIndex in
            if newIndex >= 3 {
                hasSeenSwipeHints = true
            }
        }
    }

    // MARK: - Components

    /// Progress bar showing session completion
    private var progressBar: some View {
        VStack(spacing: 4) {
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)

                    // Progress
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.black)
                        .frame(width: geometry.size.width * viewModel.progress, height: 8)
                        .animation(.easeInOut(duration: 0.3), value: viewModel.progress)
                }
            }
            .frame(height: 8)
            .accessibilityHidden(true) // Text below conveys the same info

            // Progress text
            HStack {
                Text("\(viewModel.currentIndex + 1) of \(viewModel.emails.count)")
                    .font(.caption)
                    .foregroundColor(.gray)

                Spacer()

                Text("\(viewModel.remainingEmails) remaining")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        // Combine into one VoiceOver element: "3 of 10, 7 remaining"
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Email \(viewModel.currentIndex + 1) of \(viewModel.emails.count). \(viewModel.remainingEmails) remaining.")
    }

    /// Stats row showing unsubscribe and keep counts
    private var statsRow: some View {
        HStack(spacing: 32) {
            // Unsubscribe count — combined into one VoiceOver element
            HStack(spacing: 8) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
                Text("\(viewModel.unsubscribeCount.localized)")
                    .font(.headline)
                    .foregroundColor(.black)
                Text("Unsubscribed")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(viewModel.unsubscribeCount) unsubscribed")

            Spacer()

            // Keep count — combined into one VoiceOver element
            HStack(spacing: 8) {
                Text("Kept")
                    .font(.caption)
                    .foregroundColor(.gray)
                Text("\(viewModel.keepCount.localized)")
                    .font(.headline)
                    .foregroundColor(.black)
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(viewModel.keepCount.localized) kept")
        }
    }

    /// Visual hints for swipe directions — purely decorative for sighted users.
    /// VoiceOver users get custom actions on the card instead.
    private var swipeHints: some View {
        HStack {
            // Left swipe hint
            HStack(spacing: 4) {
                Image(systemName: "arrow.left")
                Text("Unsubscribe")
            }
            .font(.caption)
            .foregroundColor(.red.opacity(0.7))

            Spacer()

            // Right swipe hint
            HStack(spacing: 4) {
                Text("Keep")
                Image(systemName: "arrow.right")
            }
            .font(.caption)
            .foregroundColor(.green.opacity(0.7))
        }
        .padding(.horizontal, 40)
        // Hints are redundant for VoiceOver — card has custom actions
        .accessibilityHidden(true)
    }
}

// MARK: - Session Complete View

/// View shown when a session is completed with stats summary.
/// Provides 3 navigation paths: New Session, View Stats, and Done (home).
struct SessionCompleteView: View {

    @ObservedObject var viewModel: SwipeViewModel

    /// Binding to the parent tab — used by "View Stats" and "Done" buttons
    @Binding var selectedTab: Tab

    /// Access gamification data for streak display
    @EnvironmentObject var gamificationViewModel: GamificationViewModel

    /// Callback to start a new swipe session
    let onNewSession: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Success icon
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)

            // Title
            Text("Session Complete!")
                .font(.title.bold())
                .foregroundColor(.black)

            // Stats summary
            statsCard

            // Points earned — combine each value+label pair for VoiceOver
            if let session = viewModel.currentSession {
                HStack(spacing: 24) {
                    VStack {
                        Text("+\(session.pointsEarned.localized)")
                            .font(.title2.bold())
                            .foregroundColor(.black)
                        Text("Points")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Plus \(session.pointsEarned.localized) points")

                    VStack {
                        Text("+\(session.xpEarned.localized)")
                            .font(.title2.bold())
                            .foregroundColor(.black)
                        Text("XP")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Plus \(session.xpEarned.localized) XP")
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 32)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
            }

            // Streak motivation — only shown when user has an active streak
            if gamificationViewModel.currentStreak > 0 {
                Text("You're on a \(gamificationViewModel.currentStreak)-day streak! Come back tomorrow to keep it going.")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            // 3-tier action buttons: primary (filled), secondary (outlined), tertiary (text)
            VStack(spacing: 12) {
                // Primary — start another session
                Button(action: onNewSession) {
                    Text("New Session")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.black)
                        .cornerRadius(12)
                }
                .accessibilityHint("Start swiping through more emails")

                // Secondary — view detailed stats
                Button {
                    selectedTab = .stats
                } label: {
                    Text("View Stats")
                        .font(.headline)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.black, lineWidth: 2)
                        )
                        .cornerRadius(12)
                }
                .accessibilityHint("Switch to the Stats tab to see your progress")

                // Tertiary — go home
                Button {
                    selectedTab = .home
                } label: {
                    Text("Done")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .accessibilityHint("Return to the Home tab")
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }

    /// Card showing session statistics
    private var statsCard: some View {
        HStack(spacing: 40) {
            // Unsubscribed
            VStack(spacing: 8) {
                Text("\(viewModel.unsubscribeCount.localized)")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.red)
                Text("Unsubscribed")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(viewModel.unsubscribeCount.localized) unsubscribed")

            // Divider — decorative, hide from VoiceOver
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 1, height: 60)
                .accessibilityHidden(true)

            // Kept
            VStack(spacing: 8) {
                Text("\(viewModel.keepCount.localized)")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.green)
                Text("Kept")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(viewModel.keepCount.localized) kept")
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 48)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.black, lineWidth: 2)
        )
        .cornerRadius(16)
    }
}

// MARK: - Error View

/// View shown when an error occurs. Displays a user-friendly error with
/// a context-specific icon, title, message, and action button.
struct ErrorView: View {

    /// User-facing error with friendly title, message, icon, and action label
    let error: UserFacingError

    /// Callback for the primary action button (retry, sign in, navigate, etc.)
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Error icon — mapped from the error type
            Image(systemName: error.iconName)
                .font(.system(size: 60))
                .foregroundColor(.orange)

            // Title — short, friendly headline
            Text(error.title)
                .font(.title.bold())
                .foregroundColor(.black)

            // Message — guidance on what happened and what to do
            Text(error.message)
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            // Action button — label matches the error context
            Button(action: onRetry) {
                Text(error.actionLabel)
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.black)
                    .cornerRadius(12)
            }
            .accessibilityLabel(error.actionLabel)
            .accessibilityHint("Attempts to resolve the error: \(error.title)")
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }
}

// MARK: - Previews

#Preview("Swipe Container - Not Started") {
    @Previewable @State var selectedTab: Tab = .swipe

    SwipeContainerView(selectedTab: $selectedTab)
        .environmentObject(GamificationViewModel())
        .modelContainer(PersistenceController.preview.container)
}

#Preview("Session Start") {
    SessionStartView(onStart: {})
}

#Preview("Loading") {
    LoadingView()
}

#Preview("Error - Network") {
    ErrorView(error: UserFacingError.from(.networkError("timeout")), onRetry: {})
}

#Preview("Error - No Emails") {
    ErrorView(error: UserFacingError.from(.noEmailsFound), onRetry: {})
}
