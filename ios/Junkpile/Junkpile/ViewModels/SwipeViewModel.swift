import Foundation
import SwiftData

/// SwipeViewModel manages the email fetching, swipe decisions, and session tracking.
/// Coordinates between the UI, API service, and local persistence.
@MainActor
final class SwipeViewModel: ObservableObject {

    // MARK: - Published State

    /// Emails available for swiping
    @Published var emails: [Email] = []

    /// Current index in the email array
    @Published var currentIndex: Int = 0

    /// Whether emails are being loaded
    @Published var isLoading = false

    /// Error message from the last operation
    @Published var errorMessage: String?

    /// Current session state
    @Published var sessionState: SessionState = .notStarted

    /// Current session (for tracking progress)
    @Published var currentSession: Session?

    /// Number of unsubscribes in current session
    @Published var unsubscribeCount: Int = 0

    /// Number of keeps in current session
    @Published var keepCount: Int = 0

    /// The most recent decision, held for the undo window.
    /// While non-nil, the user can tap Undo to roll back this decision.
    /// The API call is deferred until the undo window expires.
    @Published var pendingDecision: PendingDecision?

    /// Countdown progress for the undo timer (1.0 → 0.0 over undoDuration seconds).
    /// Drives the circular countdown ring on the UndoButton component.
    @Published var undoTimeRemaining: Double = 0

    // MARK: - Undo Types

    /// Holds all the context needed to either commit or roll back a swipe decision.
    /// Stored as the single "undo slot" — only the most recent swipe is undoable.
    struct PendingDecision {
        let email: Email
        let decision: Decision
        let action: DecisionAction
    }

    // MARK: - Session State

    /// Possible states of a swipe session
    enum SessionState: Equatable {
        case notStarted
        case loading
        case swiping
        case completed
        case error(UserFacingError)
    }

    // MARK: - Private Properties

    /// API service for backend communication
    private let apiService: APIService

    /// SwiftData model context for persistence
    private var modelContext: ModelContext?

    /// Gamification service for awarding points/XP
    private var gamificationService: GamificationService?

    /// Timer that counts down the undo window and commits the decision when it expires
    private var undoTimer: Timer?

    /// Duration in seconds of the undo window
    private let undoDuration: Double = 4.0

    /// Interval for updating the countdown ring animation (20fps)
    private let undoTimerInterval: Double = 0.05

    // MARK: - Initialization

    /// Creates a new SwipeViewModel.
    /// - Parameter apiService: Optional API service for dependency injection
    init(apiService: APIService = .shared) {
        self.apiService = apiService
    }

    /// Configures the view model with a model context for persistence.
    /// - Parameter context: The SwiftData model context
    func configure(with context: ModelContext) {
        self.modelContext = context
        self.gamificationService = GamificationService(modelContext: context)
    }

    // MARK: - Public Methods

    /// Starts a new swipe session by fetching emails from the API.
    func startSession() async {
        guard sessionState != .loading else { return }

        sessionState = .loading
        isLoading = true
        errorMessage = nil
        currentIndex = 0
        unsubscribeCount = 0
        keepCount = 0

        do {
            // Fetch emails from API
            let fetchedEmails = try await apiService.fetchEmails()

            // Update state on success
            emails = fetchedEmails

            if emails.isEmpty {
                sessionState = .error(UserFacingError.from(.noEmailsFound))
                errorMessage = "Your inbox is already clean!"
            } else {
                // Create a new session in SwiftData
                createSession(totalEmails: emails.count)
                sessionState = .swiping
            }

        } catch let error as APIError {
            // Map typed API errors to user-friendly messages
            sessionState = .error(UserFacingError.from(error))
            errorMessage = error.localizedDescription
        } catch {
            // Fallback for unexpected errors
            sessionState = .error(UserFacingError.generic())
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// Records a swipe decision for an email.
    /// The decision is persisted immediately to SwiftData (crash safety),
    /// but the API call is deferred behind a 4-second undo window.
    /// If the user taps Undo, the local persistence is rolled back
    /// and the API call never fires.
    /// - Parameters:
    ///   - email: The email that was swiped
    ///   - action: The action taken (unsubscribe or keep)
    func recordDecision(email: Email, action: DecisionAction) {
        // If there's already a pending decision from a previous swipe,
        // commit it now (fire its API call) before recording the new one.
        // Only one undo slot at a time.
        if pendingDecision != nil {
            commitPendingDecision()
        }

        // Create decision record
        let decision = Decision(
            emailId: email.id,
            emailSender: email.sender,
            emailSubject: email.subject,
            action: action,
            unsubscribeUrl: email.unsubscribeUrl
        )

        // Update local counts immediately for responsive UI
        switch action {
        case .unsubscribe:
            unsubscribeCount += 1
        case .keep:
            keepCount += 1
        }

        // Persist to SwiftData immediately (crash safety — if app is killed
        // during the undo window, the decision is not lost)
        if let context = modelContext {
            context.insert(decision)

            // Add to current session
            currentSession?.addDecision(decision)

            // Record daily activity
            let dailyActivity = context.getOrCreateDailyActivity(for: Date())
            dailyActivity.recordDecision(decision)

            // Award points/XP through gamification service
            gamificationService?.awardDecision(decision)

            // Save changes
            try? context.save()
        }

        // Store as pending instead of firing the API call immediately.
        // The API call will fire when the undo window expires or when
        // the user swipes the next card (whichever comes first).
        pendingDecision = PendingDecision(email: email, decision: decision, action: action)
        startUndoTimer()

        // Check if session is complete
        if currentIndex >= emails.count - 1 {
            completeSession()
        }
    }

    // MARK: - Undo System

    /// Commits the pending decision by firing the API call and clearing the undo state.
    /// Called when: (1) undo timer expires, (2) user swipes next card,
    /// (3) user navigates away, or (4) session resets.
    func commitPendingDecision() {
        guard let pending = pendingDecision else { return }

        // Fire the API call (fire and forget — same pattern as before)
        let emailId = pending.email.id
        let action = pending.action
        Task {
            do {
                _ = try await apiService.recordDecision(emailId: emailId, action: action)
            } catch {
                print("Failed to sync decision to backend: \(error)")
                // Decision is saved locally, will sync later
            }
        }

        // Clear undo state
        stopUndoTimer()
        pendingDecision = nil
        undoTimeRemaining = 0
    }

    /// Rolls back the most recent swipe decision.
    /// Reverses all local persistence: removes the Decision from SwiftData,
    /// reverses Session/DailyActivity/PlayerProfile counts, and decrements
    /// currentIndex so the card reappears at the top of the stack.
    func undoLastDecision() {
        guard let pending = pendingDecision else { return }

        let decision = pending.decision

        // Stop the timer — no API call should fire for this decision
        stopUndoTimer()

        // Roll back SwiftData persistence
        if let context = modelContext {
            // Reverse session counts and points
            currentSession?.removeDecision(decision)

            // Reverse daily activity counts
            let dailyActivity = context.getOrCreateDailyActivity(for: Date())
            dailyActivity.reverseDecision(decision)

            // Reverse gamification awards (points, XP, level, lifetime counts)
            gamificationService?.reverseDecision(decision)

            // Delete the Decision object from SwiftData
            context.delete(decision)

            // Persist the rollback
            try? context.save()
        }

        // Reverse local UI counts
        switch pending.action {
        case .unsubscribe:
            unsubscribeCount -= 1
        case .keep:
            keepCount -= 1
        }

        // Decrement currentIndex so the card reappears
        currentIndex -= 1

        // If the session was completed (user swiped the last card),
        // revert to swiping state so they can continue
        if sessionState == .completed {
            sessionState = .swiping
        }

        // Clear the undo slot
        pendingDecision = nil
        undoTimeRemaining = 0

        // Haptic feedback — distinct "undo" feel (warning pattern)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
    }

    /// Called by SwipeContainerView.onDisappear and resetSession() to ensure
    /// pending decisions don't linger when navigating away from the swipe view.
    func commitIfPending() {
        if pendingDecision != nil {
            commitPendingDecision()
        }
    }

    /// Starts the undo countdown timer. Updates undoTimeRemaining at 20fps
    /// to drive the countdown ring animation on the UndoButton.
    private func startUndoTimer() {
        stopUndoTimer()
        undoTimeRemaining = 1.0

        undoTimer = Timer.scheduledTimer(withTimeInterval: undoTimerInterval, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }

            Task { @MainActor in
                self.undoTimeRemaining -= self.undoTimerInterval / self.undoDuration

                // Timer expired — commit the decision and fire the API call
                if self.undoTimeRemaining <= 0 {
                    self.commitPendingDecision()
                }
            }
        }
    }

    /// Stops and invalidates the undo timer.
    private func stopUndoTimer() {
        undoTimer?.invalidate()
        undoTimer = nil
    }

    /// Completes the current session and calculates final stats.
    func completeSession() {
        guard let session = currentSession else { return }

        // Mark session as completed
        session.complete()

        // Check for session-based achievements
        gamificationService?.checkSessionAchievements(session: session)

        // Update profile stats
        gamificationService?.updateProfileStats(session: session)

        // Save changes
        try? modelContext?.save()

        // Update state
        sessionState = .completed
    }

    /// Resets the session state to start a new session.
    /// Commits any pending undo decision first to avoid data loss.
    func resetSession() {
        commitIfPending()
        emails = []
        currentIndex = 0
        unsubscribeCount = 0
        keepCount = 0
        currentSession = nil
        sessionState = .notStarted
        errorMessage = nil
    }

    /// Skips the current email without making a decision.
    /// Used for emails without unsubscribe options that user wants to skip.
    func skipCurrentEmail() {
        currentIndex += 1

        // Check if session is complete
        if currentIndex >= emails.count {
            completeSession()
        }
    }

    // MARK: - Computed Properties

    /// The currently displayed email
    var currentEmail: Email? {
        guard currentIndex < emails.count else { return nil }
        return emails[currentIndex]
    }

    /// Total number of decisions made in this session
    var totalDecisions: Int {
        return unsubscribeCount + keepCount
    }

    /// Progress through the session as a percentage (0.0 to 1.0)
    var progress: Double {
        guard !emails.isEmpty else { return 0 }
        return Double(currentIndex) / Double(emails.count)
    }

    /// Remaining emails in the session
    var remainingEmails: Int {
        return max(0, emails.count - currentIndex)
    }

    /// Whether the session can be started (not already in progress)
    var canStartSession: Bool {
        return sessionState == .notStarted || sessionState == .completed || sessionState.isError
    }

    // MARK: - Private Methods

    /// Creates a new Session in SwiftData.
    /// - Parameter totalEmails: Total number of emails in this session
    private func createSession(totalEmails: Int) {
        guard let context = modelContext else { return }

        let session = Session(totalEmails: totalEmails)
        context.insert(session)

        // Record session start in daily activity
        let dailyActivity = context.getOrCreateDailyActivity(for: Date())
        dailyActivity.recordSessionStart()

        self.currentSession = session

        try? context.save()
    }
}

// MARK: - SessionState Extension

extension SwipeViewModel.SessionState {
    /// Whether this state represents an error
    var isError: Bool {
        if case .error = self {
            return true
        }
        return false
    }

    /// User-facing error info if in error state, nil otherwise
    var errorInfo: UserFacingError? {
        if case .error(let userError) = self {
            return userError
        }
        return nil
    }
}
