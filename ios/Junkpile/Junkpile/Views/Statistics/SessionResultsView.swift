import SwiftUI
import SwiftData

/// A past session's per-email unsubscribe results, opened from Recent
/// Sessions in Stats so the list isn't lost once a new session starts.
struct SessionResultsView: View {

    let date: Date

    @Query private var sessions: [Session]

    init(sessionId: UUID, date: Date) {
        self.date = date
        _sessions = Query(filter: #Predicate<Session> { $0.id == sessionId })
    }

    private var unsubscribes: [Decision] {
        (sessions.first?.decisions ?? []).filter { $0.action == .unsubscribe }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if unsubscribes.isEmpty {
                    Text("No unsubscribes in this session.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                } else {
                    Text("Senders that need a follow-up are listed first.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    UnsubscribeResultsList(decisions: unsubscribes)
                }
            }
            .padding(16)
        }
        .navigationTitle(date.formatted(date: .abbreviated, time: .shortened))
        .navigationBarTitleDisplayMode(.inline)
    }
}
