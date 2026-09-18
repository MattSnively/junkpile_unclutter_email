import SwiftUI
import SwiftData
// Timer.publish, used for the retry countdown on ErrorView
import Combine

/// SwipeContainerView is the main container for the swipe session experience.
/// Handles the different session states: not started, loading, swiping, and complete.
struct SwipeContainerView: View {

    // MARK: - Environment

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var gamificationViewModel: GamificationViewModel
    /// Needed so an error screen can send the user back through sign-in or
    /// re-run Gmail authorisation
    @EnvironmentObject var authViewModel: AuthViewModel

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
                    ErrorView(error: userError, onAction: handleRecovery)
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

    /// Performs the recovery the error screen offered.
    ///
    /// Gmail reconnection differs by provider: an Apple user re-runs the
    /// Gmail-only OAuth flow, but that flow authenticates with a server
    /// session token, which a Google user does not have. For them a dead
    /// Gmail grant is a dead session, so the only route back is signing in
    /// again.
    private func handleRecovery(_ action: RecoveryAction) {
        switch action {
        case .retry:
            startSession()

        case .signIn:
            Task { await authViewModel.signOut() }

        case .connectGmail:
            if authViewModel.authProvider == .apple {
                Task { await authViewModel.connectGmail(from: authViewModel.keyWindow) }
            } else {
                Task { await authViewModel.signOut() }
            }

        case .showStats:
            selectedTab = .stats

        case .goHome:
            selectedTab = .home
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
                .foregroundStyle(.primary, .red)

            // Title
            Text("Ready to Clean?")
                .font(.title.bold())
                .foregroundColor(.primary)

            // Description
            Text("We'll fetch your emails with unsubscribe options.\nSwipe left to unsubscribe, right to keep.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            // Start button
            Button(action: onStart) {
                Text("Start Session")
                    .font(.headline)
                    .foregroundColor(Theme.solidFillForeground)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Theme.solidFill)
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
                .tint(.primary)
                .accessibilityLabel("Loading emails")

            Text("Fetching your emails...")
                .font(.headline)
                .foregroundColor(.secondary)
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

    // MARK: - Points Animation State

    /// Respects the user's Reduce Motion accessibility setting
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    /// Number of points earned for the most recent swipe (displayed in animation)
    @State private var pointsEarned: Int = 0

    /// Whether the points animation overlay is currently visible
    @State private var showPointsAnimation = false

    /// Vertical offset for the float-up animation (0 → -80)
    @State private var pointsAnimationOffset: CGFloat = 0

    /// Opacity for the fade-out animation (1 → 0)
    @State private var pointsAnimationOpacity: Double = 1.0

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

            // Card stack wrapped in ZStack for points animation overlay
            ZStack {
                EmailCardStack(
                    emails: viewModel.emails,
                    currentIndex: $viewModel.currentIndex
                ) { email, action in
                    viewModel.recordDecision(email: email, action: action)
                    triggerPointsAnimation(for: action)
                }

                // "+X pts" float-up text — decorative, hidden from VoiceOver
                if showPointsAnimation {
                    Text("+\(pointsEarned) pts")
                        .font(.title2.bold())
                        .foregroundColor(.primary)
                        .offset(y: pointsAnimationOffset)
                        .opacity(pointsAnimationOpacity)
                        .accessibilityHidden(true)
                }
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
                        .fill(Theme.subtleFillStrong)
                        .frame(height: 8)

                    // Progress
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Theme.solidFill)
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
                    .foregroundColor(.secondary)

                Spacer()

                Text("\(viewModel.remainingEmails) remaining")
                    .font(.caption)
                    .foregroundColor(.secondary)
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
                    .foregroundColor(.primary)
                Text("Unsubscribed")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(viewModel.unsubscribeCount) unsubscribed")

            Spacer()

            // Keep count — combined into one VoiceOver element
            HStack(spacing: 8) {
                Text("Kept")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("\(viewModel.keepCount.localized)")
                    .font(.headline)
                    .foregroundColor(.primary)
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

    // MARK: - Points Animation

    /// Triggers the "+X pts" float-up animation after a swipe decision.
    /// Unsubscribe earns 10 points, Keep earns 5 points.
    /// Reduce Motion: shows text statically for 0.8s with no movement.
    private func triggerPointsAnimation(for action: DecisionAction) {
        // Determine points based on action
        pointsEarned = action == .unsubscribe ? Decision.unsubscribePoints : Decision.keepPoints

        // Reset animation state
        pointsAnimationOffset = 0
        pointsAnimationOpacity = 1.0
        showPointsAnimation = true

        if reduceMotion {
            // Static display for 0.8s — no movement, just show and hide
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                showPointsAnimation = false
            }
        } else {
            // Animate offset upward and fade out over 1.2s
            withAnimation(.easeOut(duration: 1.2)) {
                pointsAnimationOffset = -80
                pointsAnimationOpacity = 0
            }

            // Clean up after animation completes
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                showPointsAnimation = false
            }
        }
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
                .foregroundColor(.primary)

            // Stats summary
            statsCard

            // Points earned — combine each value+label pair for VoiceOver
            if let session = viewModel.currentSession {
                HStack(spacing: 24) {
                    VStack {
                        Text("+\(session.pointsEarned.localized)")
                            .font(.title2.bold())
                            .foregroundColor(.primary)
                        Text("Points")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Plus \(session.pointsEarned.localized) points")

                    VStack {
                        Text("+\(session.xpEarned.localized)")
                            .font(.title2.bold())
                            .foregroundColor(.primary)
                        Text("XP")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Plus \(session.xpEarned.localized) XP")
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 32)
                .background(Theme.subtleFill)
                .cornerRadius(12)
            }

            // Streak motivation — only shown when user has an active streak
            if gamificationViewModel.currentStreak > 0 {
                Text("You're on a \(gamificationViewModel.currentStreak)-day streak! Come back tomorrow to keep it going.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
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
                        .foregroundColor(Theme.solidFillForeground)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Theme.solidFill)
                        .cornerRadius(12)
                }
                .accessibilityHint("Start swiping through more emails")

                // Secondary — view detailed stats
                Button {
                    selectedTab = .stats
                } label: {
                    Text("View Stats")
                        .font(.headline)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Theme.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Theme.cardBorder, lineWidth: 2)
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
                        .foregroundColor(.secondary)
                }
                .accessibilityHint("Return to the Home tab")
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }

    /// Card showing session statistics
    private var statsCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 40) {
                // Unsubscribed
                VStack(spacing: 8) {
                    Text("\(viewModel.unsubscribeCount.localized)")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.red)
                    Text("Unsubscribed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(viewModel.unsubscribeCount.localized) unsubscribed")

                // Divider — decorative, hide from VoiceOver
                Rectangle()
                    .fill(Theme.separator)
                    .frame(width: 1, height: 60)
                    .accessibilityHidden(true)

                // Kept
                VStack(spacing: 8) {
                    Text("\(viewModel.keepCount.localized)")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.green)
                    Text("Kept")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(viewModel.keepCount.localized) kept")
            }

            // What actually happened server-side to the unsubscribe requests.
            // Updates live as the deferred API calls resolve after each swipe.
            if !outcomeBreakdownParts.isEmpty {
                Text(outcomeBreakdownParts.joined(separator: " · "))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .accessibilityLabel("Unsubscribe outcomes: \(outcomeBreakdownParts.joined(separator: ", "))")
            }
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 48)
        .background(Theme.cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Theme.cardBorder, lineWidth: 2)
        )
        .cornerRadius(16)
    }

    /// Human-readable pieces of the unsubscribe outcome breakdown, e.g.
    /// ["6 confirmed", "2 attempted"]. Empty when the session had no
    /// unsubscribes. Pending = requests whose API calls have not resolved.
    private var outcomeBreakdownParts: [String] {
        guard viewModel.unsubscribeCount > 0 else { return [] }

        let counts = viewModel.sessionOutcomeCounts
        var parts: [String] = []
        for outcome in [UnsubscribeOutcome.confirmed, .attempted, .failed] {
            if let count = counts[outcome], count > 0 {
                parts.append("\(count.localized) \(outcome.displayName.lowercased())")
            }
        }

        let pending = max(0, viewModel.unsubscribeCount - counts.values.reduce(0, +))
        if pending > 0 {
            parts.append("\(pending.localized) pending")
        }
        return parts
    }
}

// MARK: - Error View

/// View shown when an error occurs. Displays a user-friendly error with
/// a context-specific icon, title, message, and action button.
struct ErrorView: View {

    /// User-facing error with friendly title, message, icon, and action label
    let error: UserFacingError

    /// Callback for the primary action. The error carries which action it is,
    /// so the caller can reconnect Gmail, sign in, or retry as appropriate.
    let onAction: (RecoveryAction) -> Void

    /// Seconds left before the action becomes available. Zero means ready.
    @State private var secondsRemaining = 0

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    /// True while a rate limit or server backoff is still counting down
    private var isWaiting: Bool { secondsRemaining > 0 }

    private var buttonLabel: String {
        isWaiting ? "Try again in \(secondsRemaining)s" : error.actionLabel
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Error icon — mapped from the error type. Decorative: the title
            // and message already carry the meaning.
            Image(systemName: error.iconName)
                .font(.system(size: 60))
                .foregroundColor(.orange)
                .accessibilityHidden(true)

            // Title — short, friendly headline
            Text(error.title)
                .font(.title.bold())
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 24)

            // Message — guidance on what happened and what to do
            Text(error.message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            // Action button — label matches the error context, and is held
            // disabled while a countdown is running so the user can't hammer
            // a rate-limited or struggling server.
            Button {
                onAction(error.action)
            } label: {
                Text(buttonLabel)
                    .font(.headline)
                    .foregroundColor(Theme.solidFillForeground)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(isWaiting ? Theme.solidFill.opacity(0.5) : Theme.solidFill)
                    .cornerRadius(12)
                    .minimumScaleFactor(0.7)
            }
            .disabled(isWaiting)
            // Static label: the per-second countdown would otherwise interrupt
            // VoiceOver every tick. The remaining wait is announced once, when
            // the user focuses the button.
            .accessibilityLabel(error.actionLabel)
            .accessibilityValue(isWaiting ? "Available in \(secondsRemaining) seconds" : "")
            .accessibilityHint(isWaiting
                ? "Waiting before this can be tried again"
                : "Double tap to \(error.actionLabel.lowercased())")
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .onAppear {
            secondsRemaining = error.retryAfterSeconds ?? 0
        }
        .onReceive(ticker) { _ in
            if secondsRemaining > 0 {
                secondsRemaining -= 1
            }
        }
    }
}

// MARK: - Previews

#Preview("Swipe Container - Not Started") {
    @Previewable @State var selectedTab: Tab = .swipe

    SwipeContainerView(selectedTab: $selectedTab)
        .environmentObject(GamificationViewModel())
        .environmentObject(AuthViewModel())
        .modelContainer(PersistenceController.preview.container)
}

#Preview("Swipe Container - Dark") {
    @Previewable @State var selectedTab: Tab = .swipe

    SwipeContainerView(selectedTab: $selectedTab)
        .environmentObject(GamificationViewModel())
        .environmentObject(AuthViewModel())
        .modelContainer(PersistenceController.preview.container)
        .preferredColorScheme(.dark)
}

#Preview("Session Start") {
    SessionStartView(onStart: {})
}

#Preview("Loading") {
    LoadingView()
}

#Preview("Error - Network") {
    ErrorView(error: UserFacingError.from(.networkError("timeout")), onAction: { _ in })
}

#Preview("Error - No Emails") {
    ErrorView(error: UserFacingError.from(.noEmailsFound), onAction: { _ in })
}

#Preview("Error - Reconnect Gmail") {
    ErrorView(error: UserFacingError.from(.gmailReauthRequired), onAction: { _ in })
}

#Preview("Error - Rate Limited") {
    ErrorView(error: UserFacingError.from(.rateLimited(retryAfterSeconds: 30)), onAction: { _ in })
}
