import SwiftUI

/// UndoButton is a floating button with a circular countdown ring
/// that appears after each swipe decision. Gives the user a 4-second
/// window to reverse their last swipe before the API call fires.
///
/// The countdown ring depletes from full (1.0) to empty (0.0) over the
/// undo duration. Tapping the button triggers the undo callback and
/// rolls back the decision. If the timer expires, the button disappears
/// and the decision is committed.
struct UndoButton: View {

    // MARK: - Properties

    /// Countdown progress (1.0 = full, 0.0 = expired). Drives the ring animation.
    let timeRemaining: Double

    /// Callback fired when the user taps Undo
    let onUndo: () -> Void

    // MARK: - Constants

    /// Size of the button circle
    private let buttonSize: CGFloat = 56

    /// Width of the countdown ring stroke
    private let ringWidth: CGFloat = 3

    // MARK: - Body

    var body: some View {
        Button(action: onUndo) {
            ZStack {
                // Background circle
                Circle()
                    .fill(Color.black)
                    .frame(width: buttonSize, height: buttonSize)

                // Countdown ring — depletes as time runs out.
                // Uses trim() to show remaining time as a partial circle stroke.
                Circle()
                    .trim(from: 0, to: max(0, timeRemaining))
                    .stroke(Color.white, lineWidth: ringWidth)
                    .rotationEffect(.degrees(-90)) // Start from top
                    .frame(width: buttonSize - ringWidth, height: buttonSize - ringWidth)

                // Undo icon and label
                VStack(spacing: 1) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)

                    Text("Undo")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white.opacity(0.9))
                }
            }
        }
        .accessibilityLabel("Undo last swipe")
        .accessibilityHint("Double tap to undo your last decision. \(Int(timeRemaining * 4)) seconds remaining.")
        // Slide up from bottom with fade
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

// MARK: - Previews

#Preview("Undo Button - Full") {
    ZStack {
        Color.gray.opacity(0.1)
        UndoButton(timeRemaining: 1.0) {
            print("Undo tapped")
        }
    }
}

#Preview("Undo Button - Half") {
    ZStack {
        Color.gray.opacity(0.1)
        UndoButton(timeRemaining: 0.5) {
            print("Undo tapped")
        }
    }
}
