import SwiftUI

/// A view modifier that adds a diagonal shimmer sweep animation over content.
/// Used on skeleton placeholder views to indicate loading state.
/// Respects Reduce Motion — shows static gray when accessibility setting is enabled.
struct ShimmerModifier: ViewModifier {

    // MARK: - Environment

    /// Respects the user's Reduce Motion accessibility setting.
    /// When enabled, the shimmer animation is disabled — shows static gray.
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    // MARK: - State

    /// Drives the shimmer gradient sweep position from left to right.
    @State private var phase: CGFloat = -1.0

    // MARK: - Body

    func body(content: Content) -> some View {
        if reduceMotion {
            // Static gray overlay when Reduce Motion is enabled — no animation
            content
                .overlay(
                    Color.gray.opacity(0.15)
                )
        } else {
            // Animated diagonal gradient sweep from left to right
            content
                .overlay(
                    GeometryReader { geometry in
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.0),
                                Color.white.opacity(0.4),
                                Color.white.opacity(0.0)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .frame(width: geometry.size.width * 1.5)
                        .offset(x: geometry.size.width * phase)
                    }
                    .clipped()
                )
                .onAppear {
                    // Continuous sweep animation — repeats forever
                    withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                        phase = 1.5
                    }
                }
        }
    }
}

// MARK: - View Extension

extension View {
    /// Applies a shimmer loading animation overlay.
    /// Respects Reduce Motion (static gray when enabled).
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}
