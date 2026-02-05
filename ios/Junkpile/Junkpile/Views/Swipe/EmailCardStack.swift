import SwiftUI

/// EmailCardStack displays a stack of email cards that can be swiped.
/// Handles drag gestures and animations for the card swiping mechanic.
struct EmailCardStack: View {

    // MARK: - Properties

    /// Emails to display as cards
    let emails: [Email]

    /// Current index in the email array
    @Binding var currentIndex: Int

    /// Callback when a swipe decision is made
    let onDecision: (Email, DecisionAction) -> Void

    // MARK: - State

    /// Current drag offset for the top card
    @State private var dragOffset: CGSize = .zero

    /// Whether the user is currently dragging
    @State private var isDragging = false

    // MARK: - Constants

    /// Threshold in pixels to trigger a swipe decision
    private let swipeThreshold: CGFloat = 100

    /// Animation for returning to center
    private let returnAnimation = Animation.spring(response: 0.4, dampingFraction: 0.7)

    /// Animation for swiping off screen
    private let swipeAnimation = Animation.easeOut(duration: 0.3)

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Display cards in reverse order so top card is rendered last
                ForEach(visibleCardIndices.reversed(), id: \.self) { index in
                    cardView(for: index, in: geometry)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Card Views

    /// Creates the view for a single card at the given index.
    /// - Parameters:
    ///   - index: The index of the email in the array
    ///   - geometry: The geometry proxy for sizing
    /// - Returns: The card view with appropriate positioning and gestures
    @ViewBuilder
    private func cardView(for index: Int, in geometry: GeometryProxy) -> some View {
        let email = emails[index]
        let isTopCard = index == currentIndex
        let offset = cardOffset(for: index)
        let scale = cardScale(for: index)

        EmailCardView(
            email: email,
            offset: isTopCard ? dragOffset : .zero,
            isDragging: isTopCard && isDragging
        )
        .frame(width: geometry.size.width - 40)
        .offset(x: isTopCard ? dragOffset.width : 0, y: offset)
        .scaleEffect(scale)
        .zIndex(Double(emails.count - index))
        .gesture(isTopCard ? dragGesture : nil)
        .animation(isTopCard ? nil : returnAnimation, value: currentIndex)
    }

    /// Indices of cards that should be visible (current + next two)
    private var visibleCardIndices: [Int] {
        let maxVisible = 3
        let startIndex = currentIndex
        let endIndex = min(currentIndex + maxVisible, emails.count)
        return Array(startIndex..<endIndex)
    }

    /// Calculates the Y offset for a card based on its position in the stack.
    /// - Parameter index: The card's index
    /// - Returns: The Y offset in points
    private func cardOffset(for index: Int) -> CGFloat {
        let positionInStack = index - currentIndex
        return CGFloat(positionInStack) * 10
    }

    /// Calculates the scale for a card based on its position in the stack.
    /// - Parameter index: The card's index
    /// - Returns: The scale factor (1.0 for top card, decreasing for cards below)
    private func cardScale(for index: Int) -> CGFloat {
        let positionInStack = index - currentIndex
        return 1.0 - (CGFloat(positionInStack) * 0.05)
    }

    // MARK: - Gestures

    /// Drag gesture for swiping the top card
    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                isDragging = true
                dragOffset = value.translation
            }
            .onEnded { value in
                handleDragEnd(translation: value.translation, velocity: value.velocity)
            }
    }

    /// Handles the end of a drag gesture, determining if a swipe occurred.
    /// - Parameters:
    ///   - translation: The final translation of the drag
    ///   - velocity: The velocity of the drag at release
    private func handleDragEnd(translation: CGSize, velocity: CGSize) {
        let horizontalSwipe = translation.width

        // Check if swipe threshold is met
        if horizontalSwipe > swipeThreshold {
            // Swipe right - Keep
            completeSwipe(direction: .right)
        } else if horizontalSwipe < -swipeThreshold {
            // Swipe left - Unsubscribe
            completeSwipe(direction: .left)
        } else {
            // Return to center
            withAnimation(returnAnimation) {
                dragOffset = .zero
                isDragging = false
            }
        }
    }

    /// Completes a swipe animation and triggers the decision callback.
    /// - Parameter direction: The swipe direction
    private func completeSwipe(direction: SwipeDirection) {
        guard currentIndex < emails.count else { return }

        let email = emails[currentIndex]
        let action: DecisionAction = direction == .left ? .unsubscribe : .keep

        // Animate card off screen
        let offScreenX: CGFloat = direction == .left ? -500 : 500

        withAnimation(swipeAnimation) {
            dragOffset = CGSize(width: offScreenX, height: 0)
        }

        // Provide haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        // Trigger callback and advance to next card after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onDecision(email, action)
            currentIndex += 1
            dragOffset = .zero
            isDragging = false
        }
    }
}

// MARK: - Supporting Types

/// Direction of a card swipe
enum SwipeDirection {
    case left
    case right
}

// MARK: - Drag Velocity Extension

extension DragGesture.Value {
    /// Calculated velocity from the drag gesture
    var velocity: CGSize {
        // Estimate velocity from predictedEndTranslation
        let dx = predictedEndTranslation.width - translation.width
        let dy = predictedEndTranslation.height - translation.height
        return CGSize(width: dx, height: dy)
    }
}

// MARK: - Previews

#Preview("Email Card Stack") {
    @Previewable @State var currentIndex = 0

    let sampleEmails = [
        Email(id: "1", sender: "Newsletter One", subject: "First Email Subject", htmlBody: "<p>Preview 1</p>", unsubscribeUrl: "https://example.com/unsub", rawHeaders: nil),
        Email(id: "2", sender: "Newsletter Two", subject: "Second Email Subject", htmlBody: "<p>Preview 2</p>", unsubscribeUrl: "https://example.com/unsub", rawHeaders: nil),
        Email(id: "3", sender: "Newsletter Three", subject: "Third Email Subject", htmlBody: "<p>Preview 3</p>", unsubscribeUrl: "https://example.com/unsub", rawHeaders: nil),
        Email(id: "4", sender: "Newsletter Four", subject: "Fourth Email Subject", htmlBody: "<p>Preview 4</p>", unsubscribeUrl: nil, rawHeaders: nil)
    ]

    return VStack {
        Text("Current: \(currentIndex + 1) / \(sampleEmails.count)")
            .padding()

        EmailCardStack(
            emails: sampleEmails,
            currentIndex: $currentIndex
        ) { email, action in
            print("Decision: \(action.rawValue) for \(email.sender)")
        }
        .padding()
    }
}
