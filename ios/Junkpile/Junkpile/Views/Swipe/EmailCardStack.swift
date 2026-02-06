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

    /// Tracks the detected axis of the current drag gesture.
    /// Once the user's initial movement exceeds axisLockThreshold,
    /// the axis locks and determines whether the gesture is treated
    /// as a swipe (horizontal) or ignored (vertical).
    @State private var gestureAxis: GestureAxis = .undetermined

    /// Prevents repeated threshold-crossing haptics within a single drag.
    /// Fires once when the user first drags past swipeThreshold, then
    /// resets when the gesture ends.
    @State private var hasTriggeredThresholdHaptic = false

    /// Guards against double-swipe race conditions. Set true when a swipe
    /// animation begins, reset false after the asyncAfter callback completes
    /// and the next card is ready. Prevents a second swipe from firing
    /// while the first is still animating off-screen.
    @State private var isProcessingSwipe = false

    // MARK: - Gesture Axis Detection

    /// Possible axis lock states for directional intent detection.
    /// Prevents accidental swipes when the user is scrolling vertically
    /// to read email card content.
    private enum GestureAxis {
        case undetermined  // Not enough movement to determine intent
        case horizontal    // User intends a swipe — card follows finger
        case vertical      // User intends a scroll — card stays put
    }

    // MARK: - Constants

    /// Threshold in pixels to trigger a swipe decision.
    /// Lowered from 100 to 75 to feel more responsive while
    /// still requiring intentional horizontal movement.
    private let swipeThreshold: CGFloat = 75

    /// Minimum movement in points before we commit to a gesture axis.
    /// Small enough to feel responsive (~4mm on iPhone), large enough
    /// to reliably read directional intent.
    private let axisLockThreshold: CGFloat = 15

    /// Ratio of horizontal-to-vertical movement required to classify as horizontal.
    /// A value of 1.5 creates a ~33-degree cone from horizontal.
    /// Intentionally generous to catch most accidental vertical scrolls.
    private let horizontalBias: CGFloat = 1.5

    /// Minimum horizontal velocity in points/sec to trigger a swipe
    /// even when the drag distance hasn't reached swipeThreshold.
    /// Allows fast "flick" gestures with short travel distance.
    private let velocityThreshold: CGFloat = 800

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
        // VoiceOver custom actions — allow swiping via rotor without drag gesture.
        // Only the top card gets actions; background cards are hidden from VoiceOver.
        .if(isTopCard) { view in
            view
                .accessibilityAddTraits(.isSelected)
                .accessibilityCustomAction("Keep") {
                    completeSwipe(direction: .right)
                    return true
                }
                .accessibilityCustomAction("Unsubscribe") {
                    completeSwipe(direction: .left)
                    return true
                }
        }
        .if(!isTopCard) { view in
            view.accessibilityHidden(true)
        }
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

    /// Drag gesture for swiping the top card.
    /// Uses directional intent detection to prevent accidental swipes
    /// when the user is scrolling vertically to read card content.
    /// Phase 1 (onChanged): determines gesture axis from initial movement.
    /// Phase 2 (onEnded): completes swipe if horizontal, returns to center otherwise.
    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                let translation = value.translation

                // Phase 1: Determine gesture axis if still undetermined.
                // We wait until the user has moved enough to read their intent
                // before committing to either horizontal (swipe) or vertical (scroll).
                if gestureAxis == .undetermined {
                    let absWidth = abs(translation.width)
                    let absHeight = abs(translation.height)
                    let totalMovement = absWidth + absHeight

                    if totalMovement > axisLockThreshold {
                        // Lock to horizontal if width dominates by the bias ratio.
                        // This creates a cone of ~33 degrees from horizontal.
                        if absWidth > absHeight * horizontalBias {
                            gestureAxis = .horizontal
                        } else {
                            gestureAxis = .vertical
                        }
                    }
                }

                // Phase 2: Only apply drag offset if axis is horizontal
                // or undetermined (small movement — card tracks finger
                // until we know the intent). Vertical axis = card stays put.
                if gestureAxis != .vertical {
                    isDragging = true
                    // Lock to horizontal component only to prevent diagonal drift
                    dragOffset = CGSize(width: translation.width, height: 0)

                    // Fire a light haptic tap the first time the user drags
                    // past the swipe threshold — confirms "this will register"
                    if !hasTriggeredThresholdHaptic && abs(translation.width) >= swipeThreshold {
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        hasTriggeredThresholdHaptic = true
                    }
                }
            }
            .onEnded { value in
                if gestureAxis == .horizontal {
                    // User intended a horizontal swipe — check thresholds
                    handleDragEnd(translation: value.translation, velocity: value.velocity)
                } else {
                    // Vertical or undetermined — snap back to center
                    withAnimation(returnAnimation) {
                        dragOffset = .zero
                        isDragging = false
                    }
                }

                // Reset axis and threshold haptic for the next gesture
                gestureAxis = .undetermined
                hasTriggeredThresholdHaptic = false
            }
    }

    /// Handles the end of a horizontal drag gesture, determining if a swipe occurred.
    /// Supports two trigger modes:
    /// 1. Position-based: drag distance exceeds swipeThreshold (75px)
    /// 2. Velocity-based: fast flick exceeds velocityThreshold (800 pts/sec)
    ///    with minimum 30px distance and same direction, allowing quick flicks
    ///    that don't travel far to still register.
    /// - Parameters:
    ///   - translation: The final translation of the drag
    ///   - velocity: The velocity of the drag at release
    private func handleDragEnd(translation: CGSize, velocity: CGSize) {
        let horizontalSwipe = translation.width
        let horizontalVelocity = velocity.width

        // Mode 1: Position threshold — drag far enough to commit
        let positionTriggered = abs(horizontalSwipe) > swipeThreshold

        // Mode 2: Velocity threshold — fast flick with minimal distance.
        // Requires: high velocity AND minimum 30px travel AND same direction
        // (prevents a fast diagonal rejection from triggering a swipe)
        let velocityTriggered = abs(horizontalVelocity) > velocityThreshold
            && abs(horizontalSwipe) > 30
            && (horizontalSwipe * horizontalVelocity > 0) // Same direction check

        if positionTriggered || velocityTriggered {
            let direction: SwipeDirection = horizontalSwipe > 0 ? .right : .left
            completeSwipe(direction: direction)
        } else {
            // Didn't meet either threshold — return to center
            withAnimation(returnAnimation) {
                dragOffset = .zero
                isDragging = false
            }
        }
    }

    /// Completes a swipe animation and triggers the decision callback.
    /// Guards against double-swipe by checking isProcessingSwipe.
    /// - Parameter direction: The swipe direction
    private func completeSwipe(direction: SwipeDirection) {
        guard currentIndex < emails.count, !isProcessingSwipe else { return }

        // Lock out additional swipes until this one finishes
        isProcessingSwipe = true

        let email = emails[currentIndex]
        let action: DecisionAction = direction == .left ? .unsubscribe : .keep

        // Animate card off screen
        let offScreenX: CGFloat = direction == .left ? -500 : 500

        withAnimation(swipeAnimation) {
            dragOffset = CGSize(width: offScreenX, height: 0)
        }

        // Direction-aware haptic: light tap for keep (gentle), medium for unsubscribe (assertive)
        let hapticStyle: UIImpactFeedbackGenerator.FeedbackStyle = direction == .right ? .light : .medium
        let generator = UIImpactFeedbackGenerator(style: hapticStyle)
        generator.impactOccurred()

        // Trigger callback and advance to next card after animation.
        // Reset isProcessingSwipe to allow the next swipe.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onDecision(email, action)
            currentIndex += 1
            dragOffset = .zero
            isDragging = false
            isProcessingSwipe = false
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

// MARK: - Conditional View Modifier

/// Conditionally applies a view modifier. Used to add accessibility
/// traits/actions only to the top card without duplicating the view builder.
extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
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
