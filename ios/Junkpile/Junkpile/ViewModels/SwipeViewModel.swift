import Foundation
import SwiftData

/// The per-decision API call the swipe flow makes. A protocol so tests can
/// stand in for the network.
protocol DecisionSyncing {
    func recordDecision(emailId: String, action: DecisionAction, trash: Bool) async throws -> DecisionAPIResponse
}

extension APIService: DecisionSyncing {}

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

    /// Server-reported outcomes for the unsubscribes sent from the review,
    /// tallied as each call resolves. Drives the session-complete breakdown.
    @Published var sessionOutcomeCounts: [UnsubscribeOutcome: Int] = [:]

    /// Unsubscribes waiting for the user to confirm them, oldest first.
    /// Includes any left over from a session the app was closed during —
    /// nothing is sent until the user confirms on the review.
    @Published private(set) var queuedUnsubscribes: [Decision] = []

    /// Queued decisions the user unchecked on the review. Confirming
    /// withdraws these instead of sending them.
    @Published var uncheckedDecisionIds: Set<UUID> = []

    /// Progress of an in-flight confirm, or nil when nothing is being sent
    @Published private(set) var sendProgress: (done: Int, total: Int)?

    /// How many unsubscribes from the last confirm never reached the server.
    /// They stay queued so the user can try again.
    @Published private(set) var unsentAfterLastSend: Int = 0

    /// "Also move these emails to Trash" on the review. Off by default and
    /// per review: deleting mail should always be a deliberate choice.
    @Published var alsoMoveToTrash = false

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

    /// Sends each decision to the backend
    private let decisionSync: DecisionSyncing

    /// Confirmed unsubscribes sent at once. Each one makes the server fetch the
    /// message and run the unsubscribe cascade, so a small cap keeps a
    /// 20-email batch quick without tripping Gmail's rate limits.
    private let maxConcurrentSends = 4

    /// Queued unsubscribes counted in unsubscribeCount, so withdrawing one
    /// only lowers that count if it was swiped in this session rather than
    /// left over from an earlier one
    private var decisionIdsThisSession: Set<UUID> = []

    // MARK: - Initialization

    /// Creates a new SwipeViewModel.
    /// - Parameters:
    ///   - apiService: Optional API service for dependency injection
    ///   - decisionSync: Where decisions are sent; defaults to apiService
    init(apiService: APIService = .shared, decisionSync: DecisionSyncing? = nil) {
        self.apiService = apiService
        self.decisionSync = decisionSync ?? apiService
    }

    /// Configures the view model with a model context for persistence.
    /// - Parameter context: The SwiftData model context
    func configure(with context: ModelContext) {
        self.modelContext = context
        self.gamificationService = GamificationService(modelContext: context)
        loadQueuedUnsubscribes()
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
        decisionIdsThisSession = []

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
    /// The decision is persisted to SwiftData immediately. A keep is sent to
    /// the server right away; an unsubscribe joins the queue and is only sent
    /// once the user confirms it on the session-end review.
    /// - Parameters:
    ///   - email: The email that was swiped
    ///   - action: The action taken (unsubscribe or keep)
    func recordDecision(email: Email, action: DecisionAction) {
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

        // Persist to SwiftData immediately so a queued unsubscribe survives
        // the app being closed before the user confirms it
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

        switch action {
        case .keep:
            // A keep changes nothing in the user's mailbox (the server only
            // stops showing that sender), so it doesn't need review
            let emailId = email.id
            Task {
                do {
                    _ = try await decisionSync.recordDecision(emailId: emailId, action: .keep, trash: false)
                } catch {
                    print("Failed to sync keep decision to backend: \(error)")
                }
            }
        case .unsubscribe:
            queuedUnsubscribes.append(decision)
            decisionIdsThisSession.insert(decision.id)
        }

        // Check if session is complete
        if currentIndex >= emails.count - 1 {
            completeSession()
        }
    }

    // MARK: - Unsubscribe Queue

    /// Number of queued unsubscribes that will be sent on confirm
    var checkedQueuedCount: Int {
        queuedUnsubscribes.filter { !uncheckedDecisionIds.contains($0.id) }.count
    }

    /// Flips a queued unsubscribe between "send" and "keep" on the review.
    func toggleQueued(_ decision: Decision) {
        if uncheckedDecisionIds.contains(decision.id) {
            uncheckedDecisionIds.remove(decision.id)
        } else {
            uncheckedDecisionIds.insert(decision.id)
        }
    }

    /// Confirms the review: withdraws unchecked decisions and sends the rest.
    /// A send that never reaches the server leaves its decision queued, so
    /// the user can retry; a server-reported failure is a final outcome.
    func sendQueuedUnsubscribes() async {
        guard sendProgress == nil else { return }

        for decision in queuedUnsubscribes where uncheckedDecisionIds.contains(decision.id) {
            withdraw(decision)
        }
        let toSend = queuedUnsubscribes.filter { !uncheckedDecisionIds.contains($0.id) }
        uncheckedDecisionIds = []
        guard !toSend.isEmpty else {
            queuedUnsubscribes = []
            unsentAfterLastSend = 0
            return
        }

        sendProgress = (0, toSend.count)
        let jobs = toSend.map { (id: $0.id, emailId: $0.emailId) }
        let sync = decisionSync
        let trash = alsoMoveToTrash
        var responses: [UUID: DecisionAPIResponse] = [:]

        await withTaskGroup(of: (UUID, DecisionAPIResponse?).self) { group in
            var nextJob = 0
            for _ in 0..<min(maxConcurrentSends, jobs.count) {
                let job = jobs[nextJob]
                nextJob += 1
                group.addTask {
                    (job.id, try? await sync.recordDecision(emailId: job.emailId, action: .unsubscribe, trash: trash))
                }
            }
            for await (id, response) in group {
                responses[id] = response
                sendProgress?.done += 1
                if nextJob < jobs.count {
                    let job = jobs[nextJob]
                    nextJob += 1
                    group.addTask {
                        (job.id, try? await sync.recordDecision(emailId: job.emailId, action: .unsubscribe, trash: trash))
                    }
                }
            }
        }

        var stillQueued: [Decision] = []
        for decision in toSend {
            // No response means the request never reached the server
            guard let response = responses[decision.id] else {
                stillQueued.append(decision)
                continue
            }
            let outcome = UnsubscribeOutcome.from(response.unsubscribeResult)
            decision.unsubscribeOutcome = outcome
            decision.unsubscribeMethod = response.unsubscribeResult?.method
            decision.movedToTrash = response.trashed
            sessionOutcomeCounts[outcome, default: 0] += 1
        }
        try? modelContext?.save()

        queuedUnsubscribes = stillQueued
        unsentAfterLastSend = stillQueued.count
        sendProgress = nil
    }

    /// Withdraws every queued unsubscribe without sending any of them.
    func discardQueuedUnsubscribes() {
        for decision in queuedUnsubscribes {
            withdraw(decision)
        }
        queuedUnsubscribes = []
        uncheckedDecisionIds = []
        unsentAfterLastSend = 0
    }

    /// Reverses a queued unsubscribe as if it had never been swiped: session
    /// and daily counts, points and XP, and the Decision itself. The sender
    /// can then appear in a future session. Achievements stay unlocked and
    /// streaks stand, since the user did act that day.
    private func withdraw(_ decision: Decision) {
        guard let context = modelContext else { return }

        owningSession(of: decision)?.removeDecision(decision)

        // The swipe may be from an earlier day if the queue was left over
        context.getOrCreateDailyActivity(for: decision.timestamp).reverseDecision(decision)
        gamificationService?.reverseDecision(decision)
        context.delete(decision)
        try? context.save()

        if decisionIdsThisSession.remove(decision.id) != nil {
            unsubscribeCount -= 1
        }
    }

    /// Decision has no back-reference to its Session, so search for it.
    private func owningSession(of decision: Decision) -> Session? {
        if let session = currentSession, session.decisions.contains(where: { $0.id == decision.id }) {
            return session
        }
        let sessions = (try? modelContext?.fetch(FetchDescriptor<Session>())) ?? []
        return sessions.first { $0.decisions.contains { $0.id == decision.id } }
    }

    /// Restores the queue from SwiftData, e.g. after the app was closed
    /// before the user confirmed their unsubscribes.
    private func loadQueuedUnsubscribes() {
        guard let context = modelContext else { return }

        // Filter the optional outcome in memory rather than in #Predicate,
        // matching StatsViewModel.loadOutcomeCounts
        let unsubscribeAction = DecisionAction.unsubscribe.rawValue
        let descriptor = FetchDescriptor<Decision>(
            predicate: #Predicate { $0.actionRawValue == unsubscribeAction },
            sortBy: [SortDescriptor(\.timestamp)]
        )
        queuedUnsubscribes = ((try? context.fetch(descriptor)) ?? [])
            .filter { $0.unsubscribeOutcome == .queued }
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

    /// Resets the session state to start a new session. Queued unsubscribes
    /// are untouched: the caller has already sent or discarded them, or they
    /// carry over to the next review.
    func resetSession() {
        emails = []
        currentIndex = 0
        unsubscribeCount = 0
        keepCount = 0
        decisionIdsThisSession = []
        sessionOutcomeCounts = [:]
        unsentAfterLastSend = 0
        alsoMoveToTrash = false
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
