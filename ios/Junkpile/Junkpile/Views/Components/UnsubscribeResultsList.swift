import SwiftUI

/// Per-email unsubscribe results: which senders were unsubscribed, which
/// weren't, and why. Used on the session-end screen and in a past session's
/// detail from Stats.
struct UnsubscribeResultsList: View {

    /// Unsubscribe decisions to show; keeps are ignored
    let decisions: [Decision]

    private var sortedUnsubscribes: [Decision] {
        decisions
            .filter { $0.action == .unsubscribe }
            .sorted {
                let left = $0.unsubscribeOutcome?.resultsSortOrder ?? UnsubscribeOutcome.pending.resultsSortOrder
                let right = $1.unsubscribeOutcome?.resultsSortOrder ?? UnsubscribeOutcome.pending.resultsSortOrder
                return left == right ? $0.timestamp < $1.timestamp : left < right
            }
    }

    var body: some View {
        let rows = sortedUnsubscribes

        VStack(spacing: 0) {
            ForEach(rows, id: \.id) { decision in
                row(for: decision)
                if decision.id != rows.last?.id {
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
    }

    private func row(for decision: Decision) -> some View {
        let outcome = decision.unsubscribeOutcome ?? .pending

        return HStack(alignment: .top, spacing: 12) {
            // Shape differs per outcome, so the status doesn't rely on color
            Image(systemName: Self.iconName(for: outcome))
                .font(.title3)
                .foregroundColor(Self.color(for: outcome))
            VStack(alignment: .leading, spacing: 2) {
                Text(decision.emailSender)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Text(decision.emailSubject)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                Text(decision.outcomeExplanation)
                    .font(.caption)
                    .foregroundColor(outcome == .confirmed ? .secondary : Self.color(for: outcome))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(decision.emailSender), \(decision.emailSubject)")
        .accessibilityValue("\(outcome.displayName). \(decision.outcomeExplanation)")
    }

    static func iconName(for outcome: UnsubscribeOutcome) -> String {
        switch outcome {
        case .confirmed: return "checkmark.circle.fill"
        case .attempted: return "questionmark.circle.fill"
        case .failed: return "xmark.octagon.fill"
        case .pending: return "clock.fill"
        case .queued: return "tray.fill"
        }
    }

    static func color(for outcome: UnsubscribeOutcome) -> Color {
        switch outcome {
        case .confirmed: return .green
        case .attempted: return .orange
        case .failed: return .red
        case .pending, .queued: return .secondary
        }
    }
}
