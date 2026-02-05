import SwiftUI
import SwiftData
import Charts

/// StatsView displays statistics and charts for the user's email management history.
struct StatsView: View {

    // MARK: - Environment

    @Environment(\.modelContext) private var modelContext

    // MARK: - State

    @StateObject private var viewModel = StatsViewModel()

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
        }
    }

    // MARK: - Components

    /// Lifetime statistics card
    private var lifetimeStatsCard: some View {
        VStack(spacing: 16) {
            Text("Lifetime Stats")
                .font(.headline)
                .foregroundColor(.black)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 16) {
                // Total emails
                statItem(
                    value: "\(viewModel.totalEmails)",
                    label: "Emails Processed",
                    icon: "envelope.fill"
                )

                // Sessions
                statItem(
                    value: "\(viewModel.totalSessions)",
                    label: "Sessions",
                    icon: "repeat"
                )
            }

            HStack(spacing: 16) {
                // Unsubscribed
                statItem(
                    value: "\(viewModel.totalUnsubscribes)",
                    label: "Unsubscribed",
                    icon: "xmark.circle.fill",
                    color: .red
                )

                // Kept
                statItem(
                    value: "\(viewModel.totalKeeps)",
                    label: "Kept",
                    icon: "checkmark.circle.fill",
                    color: .green
                )
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }

    /// Single stat item
    private func statItem(
        value: String,
        label: String,
        icon: String,
        color: Color = .black
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title3.bold())
                    .foregroundColor(.black)

                Text(label)
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer()
        }
        .padding(12)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }

    /// Weekly activity chart card
    private var weeklyChartCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("This Week")
                    .font(.headline)
                    .foregroundColor(.black)

                Spacer()

                Text("\(viewModel.weeklyTotal) emails")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }

            // Bar chart
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

                // Legend
                HStack(spacing: 24) {
                    legendItem(color: .red.opacity(0.8), label: "Unsubscribed")
                    legendItem(color: .green.opacity(0.8), label: "Kept")
                }
                .frame(maxWidth: .infinity)
            } else {
                // Empty state
                VStack(spacing: 8) {
                    Image(systemName: "chart.bar")
                        .font(.largeTitle)
                        .foregroundColor(.gray)

                    Text("No activity this week")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .frame(height: 200)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }

    /// Legend item for charts
    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)

            Text(label)
                .font(.caption)
                .foregroundColor(.gray)
        }
    }

    /// Unsubscribe/Keep ratio card
    private var ratioCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Decision Ratio")
                .font(.headline)
                .foregroundColor(.black)

            if viewModel.totalEmails > 0 {
                HStack(spacing: 24) {
                    // Donut chart
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
                                .foregroundColor(.black)

                            Text("unsub")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                    }

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
                        .foregroundColor(.gray)

                    Text("No decisions yet")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .frame(height: 100)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }

    /// Ratio breakdown row
    private func ratioRow(label: String, value: Int, percentage: Double, color: Color) -> some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)

            Text(label)
                .font(.subheadline)
                .foregroundColor(.black)

            Spacer()

            Text("\(value)")
                .font(.subheadline.bold())
                .foregroundColor(.black)

            Text("(\(Int(percentage))%)")
                .font(.caption)
                .foregroundColor(.gray)
        }
    }

    /// Session history card
    private var sessionHistoryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Sessions")
                .font(.headline)
                .foregroundColor(.black)

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
                        .foregroundColor(.gray)

                    Text("No sessions yet")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .frame(height: 100)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }

    /// Single session row
    private func sessionRow(_ session: SessionSummary) -> some View {
        HStack {
            // Date
            VStack(alignment: .leading, spacing: 2) {
                Text(session.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline)
                    .foregroundColor(.black)

                Text(session.date.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer()

            // Stats
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                        .font(.caption)
                    Text("\(session.unsubscribeCount)")
                        .font(.subheadline)
                        .foregroundColor(.black)
                }

                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                    Text("\(session.keepCount)")
                        .font(.subheadline)
                        .foregroundColor(.black)
                }
            }

            // Completion badge
            if session.isCompleted {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(.green)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Previews

#Preview("Stats View") {
    StatsView()
        .modelContainer(PersistenceController.preview.container)
}
