import SwiftUI
import SwiftData
import Charts

/// StatsView displays statistics and charts for the user's email management history.
struct StatsView: View {

    // MARK: - Environment

    @Environment(\.modelContext) private var modelContext

    // MARK: - State

    @StateObject private var viewModel = StatsViewModel()

    /// Session selected for deletion via context menu
    @State private var sessionToDelete: SessionSummary?

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Lifetime stats summary
                    lifetimeStatsCard

                    // Weekly activity chart
                    weeklyChartCard

                    // Ratio visualization
                    ratioCard

                    // Session history
                    sessionHistoryCard
                }
                .padding()
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Statistics")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                viewModel.configure(with: modelContext)
            }
            .refreshable {
                viewModel.refresh()
            }
            // Confirmation dialog for session deletion — triggered from session row context menu
            .confirmationDialog(
                "Delete Session",
                isPresented: Binding(
                    get: { sessionToDelete != nil },
                    set: { if !$0 { sessionToDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                if let session = sessionToDelete {
                    Button("Delete Session", role: .destructive) {
                        viewModel.deleteSession(id: session.id)
                        sessionToDelete = nil
                    }
                    Button("Cancel", role: .cancel) {
                        sessionToDelete = nil
                    }
                }
            } message: {
                Text("This will delete the session and adjust your lifetime stats. Streaks will not be affected. This action cannot be undone.")
            }
        }
    }

    // MARK: - Components

    /// Lifetime statistics card
    private var lifetimeStatsCard: some View {
        VStack(spacing: 16) {
            Text("Lifetime Stats")
                .font(.headline)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 16) {
                // Total emails
                statItem(
                    value: "\(viewModel.totalEmails.localized)",
                    label: "Emails Swiped",
                    icon: "envelope.fill"
                )

                // Sessions
                statItem(
                    value: "\(viewModel.totalSessions.localized)",
                    label: "Sessions",
                    icon: "repeat"
                )
            }

            HStack(spacing: 16) {
                // Unsubscribed
                statItem(
                    value: "\(viewModel.totalUnsubscribes.localized)",
                    label: "Unsubscribed",
                    icon: "xmark.circle.fill",
                    color: .red
                )

                // Kept
                statItem(
                    value: "\(viewModel.totalKeeps.localized)",
                    label: "Kept",
                    icon: "checkmark.circle.fill",
                    color: .green
                )
            }
        }
        .padding(16)
        .background(Theme.cardBackground)
        .cornerRadius(16)
        .shadow(color: Theme.shadow(opacity: 0.05), radius: 5, x: 0, y: 2)
    }

    /// Single stat item — combined into one VoiceOver element
    private func statItem(
        value: String,
        label: String,
        icon: String,
        color: Color = .primary
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title3.bold())
                    .foregroundColor(.primary)
                    .minimumScaleFactor(0.7)

                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            Spacer()
        }
        .padding(12)
        .background(Theme.subtleFill)
        .cornerRadius(12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value) \(label)")
    }

    /// Weekly activity chart card
    private var weeklyChartCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("This Week")
                    .font(.headline)
                    .foregroundColor(.primary)

                // Week-over-week trend indicator — shows the percentage change
                // compared to the previous 7 days. Only displayed when there
                // is previous week data to compare against.
                if let change = viewModel.weekOverWeekChange {
                    trendBadge(change: change)
                }

                Spacer()

                Text("\(viewModel.weeklyTotal.localized) emails")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // Bar chart — provide summary for VoiceOver since bar details are hard to navigate
            if !viewModel.weeklyData.isEmpty {
                Chart(viewModel.weeklyData) { data in
                    BarMark(
                        x: .value("Day", data.dayName),
                        y: .value("Unsubscribed", data.unsubscribes)
                    )
                    .foregroundStyle(Color.red.opacity(0.8))

                    BarMark(
                        x: .value("Day", data.dayName),
                        y: .value("Kept", data.keeps)
                    )
                    .foregroundStyle(Color.green.opacity(0.8))
                }
                .frame(height: 200)
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .accessibilityLabel("Weekly activity chart")
                .accessibilityValue("\(viewModel.weeklyTotal) emails processed this week")

                // Legend — decorative when VoiceOver is active (chart label covers it)
                HStack(spacing: 24) {
                    legendItem(color: .red.opacity(0.8), label: "Unsubscribed")
                    legendItem(color: .green.opacity(0.8), label: "Kept")
                }
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)
            } else {
                // Empty state
                VStack(spacing: 8) {
                    Image(systemName: "chart.bar")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)

                    Text("No activity this week")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(height: 200)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(16)
        .background(Theme.cardBackground)
        .cornerRadius(16)
        .shadow(color: Theme.shadow(opacity: 0.05), radius: 5, x: 0, y: 2)
    }

    /// Compact badge showing a week-over-week percentage change.
    /// Green with up arrow for positive, red with down arrow for negative,
    /// gray with dash for flat (within ±0.5%).
    private func trendBadge(change: Double) -> some View {
        let isPositive = change > 0.5
        let isNegative = change < -0.5
        let icon = isPositive ? "arrow.up.right" : (isNegative ? "arrow.down.right" : "minus")
        let color: Color = isPositive ? .green : (isNegative ? .red : .gray)

        return HStack(spacing: 2) {
            Image(systemName: icon)
                .font(.caption2)
            Text("\(Int(abs(change)))%")
                .font(.caption2.bold())
        }
        .foregroundColor(color)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(color.opacity(0.1))
        .cornerRadius(6)
        .accessibilityLabel("\(Int(abs(change))) percent \(isPositive ? "increase" : (isNegative ? "decrease" : "change")) from last week")
    }

    /// Legend item for charts
    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)

            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    /// Unsubscribe/Keep ratio card
    private var ratioCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Decision Ratio")
                .font(.headline)
                .foregroundColor(.primary)

            if viewModel.totalEmails > 0 {
                HStack(spacing: 24) {
                    // Donut chart — provide accessible summary
                    ZStack {
                        Circle()
                            .stroke(Color.green.opacity(0.3), lineWidth: 20)
                            .frame(width: 100, height: 100)

                        Circle()
                            .trim(from: 0, to: viewModel.unsubscribeRate / 100)
                            .stroke(Color.red, style: StrokeStyle(lineWidth: 20, lineCap: .round))
                            .frame(width: 100, height: 100)
                            .rotationEffect(.degrees(-90))

                        VStack(spacing: 0) {
                            Text("\(Int(viewModel.unsubscribeRate))%")
                                .font(.title3.bold())
                                .foregroundColor(.primary)

                            Text("unsub")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Unsubscribe rate \(Int(viewModel.unsubscribeRate)) percent")

                    // Stats breakdown
                    VStack(alignment: .leading, spacing: 12) {
                        ratioRow(
                            label: "Unsubscribed",
                            value: viewModel.totalUnsubscribes,
                            percentage: viewModel.unsubscribeRate,
                            color: .red
                        )

                        ratioRow(
                            label: "Kept",
                            value: viewModel.totalKeeps,
                            percentage: viewModel.keepRate,
                            color: .green
                        )
                    }
                }
            } else {
                // Empty state
                VStack(spacing: 8) {
                    Image(systemName: "chart.pie")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)

                    Text("No decisions yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(height: 100)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(16)
        .background(Theme.cardBackground)
        .cornerRadius(16)
        .shadow(color: Theme.shadow(opacity: 0.05), radius: 5, x: 0, y: 2)
    }

    /// Ratio breakdown row
    private func ratioRow(label: String, value: Int, percentage: Double, color: Color) -> some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)

            Text(label)
                .font(.subheadline)
                .foregroundColor(.primary)

            Spacer()

            Text("\(value.localized)")
                .font(.subheadline.bold())
                .foregroundColor(.primary)

            Text("(\(Int(percentage))%)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    /// Session history card
    private var sessionHistoryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Sessions")
                .font(.headline)
                .foregroundColor(.primary)

            if !viewModel.recentSessions.isEmpty {
                ForEach(viewModel.recentSessions) { session in
                    sessionRow(session)

                    if session.id != viewModel.recentSessions.last?.id {
                        Divider()
                    }
                }
            } else {
                // Empty state
                VStack(spacing: 8) {
                    Image(systemName: "clock")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)

                    Text("No sessions yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(height: 100)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(16)
        .background(Theme.cardBackground)
        .cornerRadius(16)
        .shadow(color: Theme.shadow(opacity: 0.05), radius: 5, x: 0, y: 2)
    }

    /// Single session row — combined as one VoiceOver element
    private func sessionRow(_ session: SessionSummary) -> some View {
        HStack {
            // Date
            VStack(alignment: .leading, spacing: 2) {
                Text(session.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline)
                    .foregroundColor(.primary)

                Text(session.date.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Stats
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                        .font(.caption)
                    Text("\(session.unsubscribeCount.localized)")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                }

                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                    Text("\(session.keepCount.localized)")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                }
            }

            // Completion badge
            if session.isCompleted {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(.green)
            }
        }
        .padding(.vertical, 4)
        // Long-press context menu for session deletion (ScrollView/VStack doesn't
        // support .onDelete, so we use contextMenu as the delete affordance)
        .contextMenu {
            Button(role: .destructive) {
                sessionToDelete = session
            } label: {
                Label("Delete Session", systemImage: "trash")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Session on \(session.date.formatted(date: .abbreviated, time: .shortened)). \(session.unsubscribeCount.localized) unsubscribed, \(session.keepCount.localized) kept\(session.isCompleted ? ". Completed" : "")")
    }
}

// MARK: - Previews

#Preview("Stats View") {
    StatsView()
        .modelContainer(PersistenceController.preview.container)
}

#Preview("Stats View - Dark") {
    StatsView()
        .modelContainer(PersistenceController.preview.container)
        .preferredColorScheme(.dark)
}
