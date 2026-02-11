import SwiftUI

/// EmailCardView displays a single email as a swipeable card.
/// Shows sender, subject, and preview with visual indicators for swipe direction.
struct EmailCardView: View {

    // MARK: - Properties

    /// The email to display
    let email: Email

    /// Current horizontal drag offset (for external control of card position)
    var offset: CGSize = .zero

    /// Whether the card is currently being dragged
    var isDragging: Bool = false

    // MARK: - Environment

    /// Respects the user's Reduce Motion accessibility setting.
    /// When enabled, disables the rotation3DEffect on card drag.
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    // MARK: - Constants

    /// Threshold in pixels for showing swipe indicators
    private let indicatorThreshold: CGFloat = 50

    /// Maximum rotation angle in degrees
    private let maxRotation: Double = 30

    // MARK: - Body

    var body: some View {
        ZStack {
            // Card background
            cardBackground

            // Card content
            VStack(alignment: .leading, spacing: 16) {
                // Sender and indicator row
                HStack {
                    senderSection
                    Spacer()
                    swipeIndicator
                }

                // Subject
                subjectSection

                // Divider
                Rectangle()
                    .fill(Theme.separator)
                    .frame(height: 1)
                    .accessibilityHidden(true)

                // Preview content
                previewSection

                Spacer()

                // Unsubscribe status
                unsubscribeStatus
            }
            .padding(20)
        }
        // Cap card height at 450pt, but on smaller screens (e.g. iPhone SE)
        // limit to 55% of screen height so hints/progress bar remain visible
        .frame(height: min(450, UIScreen.main.bounds.height * 0.55))
        // Gate rotation on Reduce Motion — rotation is purely decorative
        .rotation3DEffect(
            .degrees(reduceMotion ? 0 : Double(offset.width) / 40),
            axis: (x: 0, y: 0, z: 1)
        )
        // Combine the entire card into one VoiceOver element so it reads
        // as a single coherent description rather than traversing child views
        .accessibilityElement(children: .combine)
        .accessibilityLabel(cardAccessibilityLabel)
        .accessibilityHint(email.hasUnsubscribeOption
            ? "Unsubscribe link available. Use custom actions to keep or unsubscribe."
            : "Manual unsubscribe may be required. Use custom actions to keep or unsubscribe.")
    }

    // MARK: - Accessibility

    /// Composed accessibility label for the entire card, read as a single VoiceOver element.
    /// Format: "Email from [sender]. Subject: [subject]."
    private var cardAccessibilityLabel: String {
        let subject = email.subject.isEmpty ? "No subject" : email.subject
        return "Email from \(email.sender). Subject: \(subject)."
    }

    // MARK: - Components

    /// Card background with border color based on swipe direction
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Theme.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(borderColor, lineWidth: 3)
            )
            .shadow(color: Theme.shadow(opacity: 0.1), radius: 10, x: 0, y: 5)
    }

    /// Border color changes based on swipe direction
    private var borderColor: Color {
        if offset.width > indicatorThreshold {
            return .green // Keep
        } else if offset.width < -indicatorThreshold {
            return .red // Unsubscribe
        }
        return Theme.cardBorder
    }

    /// Sender information section
    private var senderSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("From")
                .font(.caption)
                .foregroundColor(.secondary)

            Text(email.sender)
                .font(.headline)
                .foregroundColor(.primary)
                .lineLimit(1)
        }
    }

    /// Swipe direction indicator
    @ViewBuilder
    private var swipeIndicator: some View {
        if offset.width > indicatorThreshold {
            // Keep indicator
            HStack(spacing: 4) {
                Text("KEEP")
                    .font(.caption.bold())
                Image(systemName: "checkmark.circle.fill")
            }
            .foregroundColor(.green)
            .transition(.opacity)
        } else if offset.width < -indicatorThreshold {
            // Unsubscribe indicator
            HStack(spacing: 4) {
                Image(systemName: "xmark.circle.fill")
                Text("UNSUB")
                    .font(.caption.bold())
            }
            .foregroundColor(.red)
            .transition(.opacity)
        }
    }

    /// Subject line section
    private var subjectSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Subject")
                .font(.caption)
                .foregroundColor(.secondary)

            Text(email.subject.isEmpty ? "(No Subject)" : email.subject)
                .font(.body)
                .foregroundColor(.primary)
                .lineLimit(3)
        }
    }

    /// Email preview section
    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Preview")
                .font(.caption)
                .foregroundColor(.secondary)

            // Show email preview or a placeholder
            if let htmlBody = email.htmlBody, !htmlBody.isEmpty {
                // Strip HTML and show plain text preview
                Text(htmlBody.strippingHTML().prefix(300))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(8)
            } else {
                Text("No preview available")
                    .font(.subheadline)
                    .foregroundColor(.secondary.opacity(0.6))
                    .italic()
            }
        }
    }

    /// Unsubscribe availability status
    private var unsubscribeStatus: some View {
        HStack {
            if email.hasUnsubscribeOption {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Unsubscribe available")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("Manual unsubscribe may be required")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
    }
}

// MARK: - String Extension for HTML Stripping

extension String {
    /// Strips HTML tags from the string and returns plain text.
    /// Used for displaying email preview without HTML formatting.
    func strippingHTML() -> String {
        // Remove HTML tags
        var result = self.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)

        // Decode common HTML entities
        let entities: [String: String] = [
            "&nbsp;": " ",
            "&amp;": "&",
            "&lt;": "<",
            "&gt;": ">",
            "&quot;": "\"",
            "&#39;": "'",
            "&mdash;": "—",
            "&ndash;": "–"
        ]

        for (entity, replacement) in entities {
            result = result.replacingOccurrences(of: entity, with: replacement)
        }

        // Clean up whitespace
        result = result.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)

        return result
    }
}

// MARK: - Previews

#Preview("Email Card - Default") {
    EmailCardView(email: Email(
        id: "1",
        sender: "Newsletter Company",
        subject: "Your Weekly Update - Don't miss these great deals and exclusive offers",
        htmlBody: "<p>Hello! Here's your weekly newsletter with all the latest updates and deals you don't want to miss. Check out our new products and exclusive member offers.</p>",
        unsubscribeUrl: "https://example.com/unsubscribe",
        rawHeaders: nil
    ))
    .padding()
}

#Preview("Email Card - Swiping Right") {
    EmailCardView(
        email: Email(
            id: "1",
            sender: "Important Service",
            subject: "Account Security Update",
            htmlBody: "<p>Important information about your account security.</p>",
            unsubscribeUrl: "https://example.com/unsubscribe",
            rawHeaders: nil
        ),
        offset: CGSize(width: 100, height: 0),
        isDragging: true
    )
    .padding()
}

#Preview("Email Card - Swiping Left") {
    EmailCardView(
        email: Email(
            id: "1",
            sender: "Spam Newsletter",
            subject: "Buy now! Limited time offer!",
            htmlBody: "<p>Don't miss this amazing deal!</p>",
            unsubscribeUrl: "https://example.com/unsubscribe",
            rawHeaders: nil
        ),
        offset: CGSize(width: -100, height: 0),
        isDragging: true
    )
    .padding()
}

#Preview("Email Card - No Unsubscribe") {
    EmailCardView(email: Email(
        id: "1",
        sender: "Some Sender",
        subject: "A message without unsubscribe option",
        htmlBody: "<p>This email doesn't have an unsubscribe link.</p>",
        unsubscribeUrl: nil,
        rawHeaders: nil
    ))
    .padding()
}
