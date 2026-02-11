import SwiftUI

/// SkeletonLoadingView replaces the simple spinner LoadingView with content-shaped
/// skeleton placeholders. Shows 2-3 stacked skeleton cards mimicking the EmailCardStack
/// layout (10pt Y offset, 0.95 scale per card) so users can anticipate the swipe UI.
struct SkeletonLoadingView: View {

    var body: some View {
        VStack(spacing: 0) {
            // Title area placeholder — matches SwipeView's progress bar area
            VStack(spacing: 8) {
                skeletonRect(width: .infinity, height: 8, cornerRadius: 4)
                    .padding(.horizontal, 20)

                HStack {
                    skeletonRect(width: 80, height: 12)
                    Spacer()
                    skeletonRect(width: 90, height: 12)
                }
                .padding(.horizontal, 20)
            }
            .padding(.top, 8)
            .shimmer()

            // Skeleton card stack — 3 cards with decreasing scale and increasing offset,
            // matching EmailCardStack's visual layout
            ZStack {
                // Third card (bottom of stack)
                SkeletonCardView()
                    .offset(y: 20)
                    .scaleEffect(0.90)
                    .opacity(0.4)

                // Second card (middle)
                SkeletonCardView()
                    .offset(y: 10)
                    .scaleEffect(0.95)
                    .opacity(0.6)

                // Top card (fully visible)
                SkeletonCardView()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)

            // Loading text
            Text("Fetching your emails...")
                .font(.headline)
                .foregroundColor(.secondary)
                .padding(.bottom, 20)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading emails")
    }

    // MARK: - Helpers

    /// Creates a rounded rectangle placeholder with the given dimensions.
    private func skeletonRect(width: CGFloat, height: CGFloat, cornerRadius: CGFloat = 4) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Theme.subtleFill)
            .frame(maxWidth: width == .infinity ? .infinity : width, alignment: .leading)
            .frame(width: width == .infinity ? nil : width)
            .frame(height: height)
    }
}

// MARK: - Previews

#Preview("Skeleton Loading View") {
    SkeletonLoadingView()
}
