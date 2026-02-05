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

    // MARK: - Session State

    /// Possible states of a swipe session
    enum SessionState: Equatable {
        case notStarted
        case loading
        case swiping
        case completed
        case error(String)
    }

    // MARK: - Private Properties

    /// API service for backend communication
    private let apiService: APIService

    /// SwiftData model context for persistence
    private var modelContext: ModelContext?

    /// Gamification service for awarding points/XP
    private var gamificationService: GamificationService?

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
                sessionState = .error("No emails with unsubscribe options found")
                errorMessage = "Your inbox is already clean!"
            } else {
                // Create a new session in SwiftData
                createSession(totalEmails: emails.count)
                sessionState = .swiping
            }

        } catch let error as APIError {
            sessionState = .error(error.localizedDescription)
            errorMessage = error.localizedDescription
        } catch {
            sessionState = .error(error.localizedDescription)
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// Records a swipe decision for an email.
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

        // Update local counts
        switch action {
        case .unsubscribe:
            unsubscribeCount += 1
        case .keep:
            keepCount += 1
        }

        // Persist to SwiftData
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

        // Send to backend API (fire and forget)
        Task {
            do {
                _ = try await apiService.recordDecision(emailId: email.id, action: action)
            } catch {
                print("Failed to sync decision to backend: \(error)")
                // Decision is saved locally, will sync later
            }
        }

        // Check if session is complete
        if currentIndex >= emails.count - 1 {
            completeSession()
        }
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
    func resetSession() {
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

    /// Error message if in error state, nil otherwise
    var errorMessage: String? {
        if case .error(let message) = self {
            return message
        }
        return nil
    }
}
