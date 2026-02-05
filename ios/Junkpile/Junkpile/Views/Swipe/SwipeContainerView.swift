import SwiftUI
import SwiftData

/// SwipeContainerView is the main container for the swipe session experience.
/// Handles the different session states: not started, loading, swiping, and complete.
struct SwipeContainerView: View {

    // MARK: - Environment

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var gamificationViewModel: GamificationViewModel

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
                    LoadingView()

                case .swiping:
                    SwipeView(viewModel: viewModel)

                case .completed:
                    SessionCompleteView(
                        viewModel: viewModel,
                        onNewSession: { viewModel.resetSession() }
                    )

                case .error(let message):
                    ErrorView(message: message, onRetry: startSession)
                }
            }
            .navigationTitle("Swipe")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                viewModel.configure(with: modelContext)
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

            // Swipe hints
            swipeHints
                .padding(.bottom, 20)
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
    }

    /// Stats row showing unsubscribe and keep counts
    private var statsRow: some View {
        HStack(spacing: 32) {
            // Unsubscribe count
            HStack(spacing: 8) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
                Text("\(viewModel.unsubscribeCount)")
                    .font(.headline)
                    .foregroundColor(.black)
                Text("Unsubscribed")
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer()

            // Keep count
            HStack(spacing: 8) {
                Text("Kept")
                    .font(.caption)
                    .foregroundColor(.gray)
                Text("\(viewModel.keepCount)")
                    .font(.headline)
                    .foregroundColor(.black)
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
        }
    }

    /// Visual hints for swipe directions
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
    }
}

// MARK: - Session Complete View

/// View shown when a session is completed with stats summary
struct SessionCompleteView: View {

    @ObservedObject var viewModel: SwipeViewModel
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

            // Points earned
            if let session = viewModel.currentSession {
                HStack(spacing: 24) {
                    VStack {
                        Text("+\(session.pointsEarned)")
                            .font(.title2.bold())
                            .foregroundColor(.black)
                        Text("Points")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }

                    VStack {
                        Text("+\(session.xpEarned)")
                            .font(.title2.bold())
                            .foregroundColor(.black)
                        Text("XP")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 32)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
            }

            Spacer()

            // Action buttons
            VStack(spacing: 12) {
                Button(action: onNewSession) {
                    Text("New Session")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.black)
                        .cornerRadius(12)
                }
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
                Text("\(viewModel.unsubscribeCount)")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.red)
                Text("Unsubscribed")
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            // Divider
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 1, height: 60)

            // Kept
            VStack(spacing: 8) {
                Text("\(viewModel.keepCount)")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.green)
                Text("Kept")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
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

/// View shown when an error occurs
struct ErrorView: View {

    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Error icon
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)

            // Title
            Text("Oops!")
                .font(.title.bold())
                .foregroundColor(.black)

            // Error message
            Text(message)
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            // Retry button
            Button(action: onRetry) {
                Text("Try Again")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.black)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }
}

// MARK: - Previews

#Preview("Swipe Container - Not Started") {
    SwipeContainerView()
        .environmentObject(GamificationViewModel())
        .modelContainer(PersistenceController.preview.container)
}

#Preview("Session Start") {
    SessionStartView(onStart: {})
}

#Preview("Loading") {
    LoadingView()
}

#Preview("Error") {
    ErrorView(message: "Failed to fetch emails. Please check your connection.", onRetry: {})
}
