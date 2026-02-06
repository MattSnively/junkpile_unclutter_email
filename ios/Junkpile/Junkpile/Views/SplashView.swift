import SwiftUI

/// SplashView is a branded loading screen shown during initial credential validation.
/// Prevents the onboarding view from flashing when a returning user's token is being
/// validated at app launch. Shows the Junkpile logo and a subtle loading indicator.
struct SplashView: View {

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // App icon and name with shimmer effect for a branded loading feel
            VStack(spacing: 24) {
                // App icon — matches the onboarding welcome page icon
                Image(systemName: "envelope.badge.shield.half.filled")
                    .font(.system(size: 80))
                    .foregroundStyle(.black, .red)
                    .accessibilityHidden(true)

                // App name
                Text("Junkpile")
                    .font(.largeTitle.bold())
                    .foregroundColor(.black)
            }
            .shimmer()

            // Loading indicator — shows that credentials are being checked
            ProgressView()
                .tint(.black)
                .accessibilityLabel("Loading")
                .accessibilityHint("Checking your saved credentials")

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
    }
}

// MARK: - Previews

#Preview("Splash View") {
    SplashView()
}
