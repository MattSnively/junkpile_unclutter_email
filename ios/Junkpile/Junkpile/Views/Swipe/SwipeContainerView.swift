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

    /// Whether the review sheet for leftover queued unsubscribes is open
    @State private var isReviewingLeftovers = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.sessionState {
                case .notStarted:
                    SessionStartView(onStart: startSession)
                        // Unsubscribes left unconfirmed when the app was
                        // closed mid-session. Never sent without a review.
                        .safeAreaInset(edge: .top) {
                            if !viewModel.queuedUnsubscribes.isEmpty {
                                leftoverQueueBanner
                            }
                        }

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
            .navigationTitle("Swipe")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                viewModel.configure(with: modelContext)
            }
            .sheet(isPresented: $isReviewingLeftovers) {
                NavigationStack {
                    ScrollView {
                        QueuedUnsubscribeReview(viewModel: viewModel)
                            .padding(24)
                    }
                    .navigationTitle("Waiting to Send")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Close") { isReviewingLeftovers = false }
                        }
                    }
                }
                // Close once everything has been sent or withdrawn
                .onChange(of: viewModel.queuedUnsubscribes.isEmpty) { _, isEmpty in
                    if isEmpty { isReviewingLeftovers = false }
                }
            }
        }
    }

    private var leftoverQueueBanner: some View {
        Button {
            isReviewingLeftovers = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "tray.full.fill")
                    .foregroundColor(.orange)
                    .accessibilityHidden(true)
                Text("You have \(viewModel.queuedUnsubscribes.count.localized) unsubscribes waiting to send")
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                Text("Review")
                    .font(.subheadline.bold())
                    .foregroundColor(.accentColor)
            }
            .padding(16)
            .background(Theme.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Theme.cardBorder, lineWidth: 1)
            )
            .cornerRadius(12)
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(viewModel.queuedUnsubscribes.count.localized) unsubscribes waiting to send")
        .accessibilityHint("Review and send them, or keep those senders")
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

    /// Shown when New Session is tapped with unsubscribes still unconfirmed
    @State private var isConfirmingNewSession = false

    var body: some View {
        // Scrolls because the review list can hold a whole batch of senders
        ScrollView {
            VStack(spacing: 32) {
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

                // Nothing is unsubscribed until the user confirms here
                if !viewModel.queuedUnsubscribes.isEmpty {
                    QueuedUnsubscribeReview(viewModel: viewModel)
                        .padding(.horizontal, 24)
                }

                // Per-email outcomes once anything has been sent, so the
                // user can see which senders need a manual follow-up
                if !sentUnsubscribes.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Results")
                            .font(.headline)
                            .foregroundColor(.primary)
                            .accessibilityAddTraits(.isHeader)
                        UnsubscribeResultsList(decisions: sentUnsubscribes)
                    }
                    .padding(.horizontal, 24)
                }

                // Streak motivation — only shown when user has an active streak
                if gamificationViewModel.currentStreak > 0 {
                    Text("You're on a \(gamificationViewModel.currentStreak)-day streak! Come back tomorrow to keep it going.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                // 3-tier action buttons: primary (filled), secondary (outlined), tertiary (text)
                VStack(spacing: 12) {
                    // Primary — start another session
                    Button {
                        if viewModel.queuedUnsubscribes.isEmpty {
                            onNewSession()
                        } else {
                            isConfirmingNewSession = true
                        }
                    } label: {
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
            .padding(.top, 32)
        }
        .confirmationDialog(
            "You have \(viewModel.checkedQueuedCount.localized) unsubscribes that haven't been sent.",
            isPresented: $isConfirmingNewSession,
            titleVisibility: .visible
        ) {
            Button("Send and Start New Session") {
                Task {
                    await viewModel.sendQueuedUnsubscribes()
                    onNewSession()
                }
            }
            Button("Discard and Start New Session", role: .destructive) {
                viewModel.discardQueuedUnsubscribes()
                onNewSession()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Discarding keeps those senders; they may show up in a future session.")
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

    /// This session's unsubscribes that have left the review queue
    private var sentUnsubscribes: [Decision] {
        (viewModel.currentSession?.decisions ?? []).filter {
            $0.action == .unsubscribe && $0.unsubscribeOutcome != .queued
        }
    }

    /// Human-readable pieces of the unsubscribe outcome breakdown, e.g.
    /// ["6 confirmed", "2 attempted"]. Empty when the session had no
    /// unsubscribes. "Not sent" covers everything still waiting on the review.
    private var outcomeBreakdownParts: [String] {
        guard viewModel.unsubscribeCount > 0 else { return [] }

        let counts = viewModel.sessionOutcomeCounts
        var parts: [String] = []
        for outcome in [UnsubscribeOutcome.confirmed, .attempted, .failed] {
            if let count = counts[outcome], count > 0 {
                parts.append("\(count.localized) \(outcome.displayName.lowercased())")
            }
        }

        let notSent = max(0, viewModel.unsubscribeCount - counts.values.reduce(0, +))
        if notSent > 0 {
            parts.append("\(notSent.localized) not sent")
        }
        return parts
    }
}

// MARK: - Queued Unsubscribe Review

/// Checklist of queued unsubscribes with the button that sends them. Shown on
/// the session-end screen, and in a sheet for a queue left over from a
/// session the app was closed during.
struct QueuedUnsubscribeReview: View {

    @ObservedObject var viewModel: SwipeViewModel

    @State private var isConfirmingDiscard = false

    private var isSending: Bool { viewModel.sendProgress != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Review Unsubscribes")
                .font(.headline)
                .foregroundColor(.primary)
                .accessibilityAddTraits(.isHeader)

            Text("Uncheck any sender you'd rather keep. Nothing is sent until you confirm.")
                .font(.caption)
                .foregroundColor(.secondary)

            VStack(spacing: 0) {
                ForEach(viewModel.queuedUnsubscribes, id: \.id) { decision in
                    row(for: decision)
                    if decision.id != viewModel.queuedUnsubscribes.last?.id {
                        Divider()
                            .padding(.leading, 48)
                            .accessibilityHidden(true)
                    }
                }
            }
            .background(Theme.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Theme.cardBorder, lineWidth: 1)
            )
            .cornerRadius(12)

            Toggle(isOn: $viewModel.alsoMoveToTrash) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Also move these emails to Trash")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    Text("Only the email shown on each checked card. Gmail keeps Trash for 30 days.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .disabled(isSending || viewModel.checkedQueuedCount == 0)

            if viewModel.unsentAfterLastSend > 0 && !isSending {
                Text("\(viewModel.unsentAfterLastSend.localized) couldn't be sent. Check your connection and try again.")
                    .font(.caption)
                    .foregroundColor(.orange)
            }

            if let progress = viewModel.sendProgress {
                ProgressView(value: Double(progress.done), total: Double(max(progress.total, 1))) {
                    Text("Unsubscribing \(progress.done.localized) of \(progress.total.localized)…")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(height: 56)
            } else {
                Button {
                    Task { await viewModel.sendQueuedUnsubscribes() }
                } label: {
                    Text(sendButtonTitle)
                        .font(.headline)
                        .foregroundColor(Theme.solidFillForeground)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Theme.solidFill)
                        .cornerRadius(12)
                }
                .accessibilityHint(viewModel.checkedQueuedCount > 0
                    ? "Sends unsubscribe requests for the checked senders"
                    : "Keeps every sender in this list")

                Button("Discard All") {
                    isConfirmingDiscard = true
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
                .accessibilityHint("Keeps every sender without sending anything")
            }
        }
        .confirmationDialog(
            "Keep all \(viewModel.queuedUnsubscribes.count.localized) senders?",
            isPresented: $isConfirmingDiscard,
            titleVisibility: .visible
        ) {
            Button("Discard All", role: .destructive) {
                viewModel.discardQueuedUnsubscribes()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Nothing will be sent, and the points for these swipes are removed.")
        }
    }

    private var sendButtonTitle: String {
        let count = viewModel.checkedQueuedCount
        return count > 0 ? "Unsubscribe (\(count.localized))" : "Keep All"
    }

    private func row(for decision: Decision) -> some View {
        let isChecked = !viewModel.uncheckedDecisionIds.contains(decision.id)

        return Button {
            viewModel.toggleQueued(decision)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(isChecked ? .red : .secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(decision.emailSender)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Text(decision.emailSubject)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isSending)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(decision.emailSender), \(decision.emailSubject)")
        .accessibilityValue(isChecked ? "Will unsubscribe" : "Will keep")
        .accessibilityHint(isChecked ? "Double tap to keep this sender instead" : "Double tap to unsubscribe from this sender")
        .accessibilityAddTraits(.isButton)
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
