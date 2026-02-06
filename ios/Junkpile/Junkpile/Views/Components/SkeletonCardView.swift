import SwiftUI

/// SkeletonCardView mimics the layout of EmailCardView with gray placeholder
/// rectangles in place of text. Provides a content-shaped loading indicator
/// so users can anticipate what the loaded screen will look like.
/// Matches EmailCardView's padding (20pt), spacing (16pt), and corner radius (16pt).
struct SkeletonCardView: View {

    var body: some View {
        ZStack {
            // Card background — matches EmailCardView's card style
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1.5)
                )
                .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)

            // Placeholder content — mirrors EmailCardView's VStack layout
            VStack(alignment: .leading, spacing: 16) {
                // Sender placeholder row (label + name)
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        // "From" label placeholder
                        skeletonRect(width: 40, height: 10)

                        // Sender name placeholder
                        skeletonRect(width: 180, height: 16)
                    }

                    Spacer()
                }

                // Subject placeholder (label + text)
                VStack(alignment: .leading, spacing: 6) {
                    // "Subject" label placeholder
                    skeletonRect(width: 55, height: 10)

                    // Subject text placeholder — two lines
                    skeletonRect(width: .infinity, height: 14)
                    skeletonRect(width: 220, height: 14)
                }

                // Divider placeholder
                skeletonRect(width: .infinity, height: 1)

                // Preview placeholder (label + lines)
                VStack(alignment: .leading, spacing: 6) {
                    // "Preview" label placeholder
                    skeletonRect(width: 50, height: 10)

                    // Preview text — multiple lines
                    skeletonRect(width: .infinity, height: 12)
                    skeletonRect(width: .infinity, height: 12)
                    skeletonRect(width: 160, height: 12)
                }

                Spacer()

                // Unsubscribe status placeholder
                HStack(spacing: 6) {
                    skeletonRect(width: 16, height: 16, cornerRadius: 8)
                    skeletonRect(width: 140, height: 12)
                }
            }
            .padding(20)
        }
        // Match EmailCardView height constraints
        .frame(height: min(450, UIScreen.main.bounds.height * 0.55))
        // Apply shimmer animation over the entire card
        .shimmer()
    }

    // MARK: - Helpers

    /// Creates a rounded rectangle placeholder with the given dimensions.
    /// - Parameters:
    ///   - width: Width of the placeholder (use `.infinity` for full width)
    ///   - height: Height of the placeholder
    ///   - cornerRadius: Corner radius (defaults to 4pt)
    private func skeletonRect(width: CGFloat, height: CGFloat, cornerRadius: CGFloat = 4) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.gray.opacity(0.15))
            .frame(maxWidth: width == .infinity ? .infinity : width, alignment: .leading)
            .frame(width: width == .infinity ? nil : width)
            .frame(height: height)
    }
}

// MARK: - Previews

#Preview("Skeleton Card") {
    SkeletonCardView()
        .padding()
}
