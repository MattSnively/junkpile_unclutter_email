import SwiftUI

/// DisclaimerView presents legal disclaimers covering user responsibility,
/// irreversibility, service limitations, and data scope.
/// Follows the DataInfoView pattern: ScrollView > VStack > sections with Label headers.
/// Full VoiceOver accessibility support.
struct DisclaimerView: View {

    // MARK: - Environment

    @Environment(\.dismiss) var dismiss

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // Section 1: User Responsibility
                    disclaimerSection(
                        icon: "hand.tap",
                        title: "User Responsibility",
                        body: "All unsubscribe actions are initiated by you through Junkpile's swipe interface. Junkpile executes your expressed intent by sending unsubscribe requests on your behalf. You are responsible for reviewing each email before swiping."
                    )

                    Divider()

                    // Section 2: Irreversibility
                    disclaimerSection(
                        icon: "arrow.uturn.backward.circle",
                        title: "Irreversibility",
                        body: "Unsubscribe requests sent through Junkpile cannot be reversed through the app. If you wish to receive emails from a sender you previously unsubscribed from, you must re-subscribe directly with that sender."
                    )

                    Divider()

                    // Section 3: No Guarantee of Effectiveness
                    disclaimerSection(
                        icon: "exclamationmark.triangle",
                        title: "No Guarantee of Effectiveness",
                        body: "Unsubscribe requests are sent using List-Unsubscribe headers and links provided by senders. Some senders may not honor these requests, may delay processing, or may continue sending emails despite the request."
                    )

                    Divider()

                    // Section 4: No Liability for Missed Communications
                    disclaimerSection(
                        icon: "envelope.open",
                        title: "No Liability for Missed Communications",
                        body: "Junkpile is not responsible for any emails, newsletters, account notifications, or other communications that you chose to unsubscribe from. Review each sender carefully before making your decision."
                    )

                    Divider()

                    // Section 5: Email Access Scope
                    disclaimerSection(
                        icon: "lock.shield",
                        title: "Email Access Scope",
                        body: "Junkpile only accesses email metadata (sender, subject, unsubscribe links) and does not read, store, or process the full content of your emails. Access is limited to what is necessary to identify unsubscribe options."
                    )

                    Divider()

                    // Section 6: Service Availability
                    disclaimerSection(
                        icon: "icloud",
                        title: "Service Availability",
                        body: "Junkpile depends on the Google Gmail API to access your email data. Service interruptions, API changes, or connectivity issues may temporarily or permanently affect the app's functionality."
                    )

                    Divider()

                    // Section 7: Last Updated date
                    Text("Last Updated: February 2026")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 8)
                }
                .padding()
            }
            .navigationTitle("Disclaimer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Components

    /// A single disclaimer section with a Label header and body text.
    /// Follows the DataInfoView pattern for consistency.
    /// - Parameters:
    ///   - icon: SF Symbol name for the section icon
    ///   - title: Section heading text
    ///   - body: Section body text
    private func disclaimerSection(icon: String, title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.headline)

            Text(body)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Previews

#Preview("Disclaimer View") {
    DisclaimerView()
}
