import SwiftUI

/// OnboardingView is the main entry point for unauthenticated users.
/// Guides users through the app introduction and sign-in process.
/// Presents both Apple and Google sign-in options via SignInView.
struct OnboardingView: View {

    // MARK: - Environment

    @EnvironmentObject var authViewModel: AuthViewModel

    // MARK: - State

    /// Current page in the onboarding carousel
    @State private var currentPage = 0

    /// Whether to show the sign-in view
    @State private var showSignIn = false

    // MARK: - Body

    var body: some View {
        ZStack {
            // Background — adaptive for dark mode
            Theme.cardBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Page indicator and skip button
                header

                // Onboarding pages
                TabView(selection: $currentPage) {
                    WelcomePage()
                        .tag(0)

                    HowItWorksPage()
                        .tag(1)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Page dots
                pageIndicator
                    .padding(.vertical, 20)

                // Action button
                actionButton
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
            }
        }
        .sheet(isPresented: $showSignIn) {
            SignInView()
        }
    }

    // MARK: - Components

    /// Header with skip button
    private var header: some View {
        HStack {
            Spacer()

            // Skip button (only on first page — page 1 is the last page)
            if currentPage < 1 {
                Button("Skip") {
                    withAnimation {
                        currentPage = 1
                    }
                }
                .font(.body)
                .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .frame(height: 44)
    }

    /// Page indicator dots — VoiceOver reads current position
    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<2, id: \.self) { index in
                Circle()
                    .fill(index == currentPage ? Theme.solidFill : Theme.separator)
                    .frame(width: 8, height: 8)
                    .animation(.easeInOut(duration: 0.2), value: currentPage)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Page \(currentPage + 1) of 2")
    }

    /// Primary action button — "Next" on page 0, "Get Started" on page 1 (final page)
    private var actionButton: some View {
        Button {
            if currentPage < 1 {
                withAnimation {
                    currentPage += 1
                }
            } else {
                showSignIn = true
            }
        } label: {
            Text(currentPage < 1 ? "Next" : "Get Started")
                .font(.headline)
                .foregroundColor(Theme.solidFillForeground)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Theme.solidFill)
                .cornerRadius(12)
        }
        .accessibilityLabel(currentPage < 1 ? "Next" : "Get Started")
        .accessibilityHint(currentPage < 1 ? "Go to next onboarding page" : "Sign in to start using Junkpile")
    }
}

// MARK: - Welcome Page

/// First onboarding page introducing the app concept
struct WelcomePage: View {

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // App icon/illustration
            Image(systemName: "envelope.badge.shield.half.filled")
                .font(.system(size: 100))
                .foregroundStyle(.primary, .red)

            // Title
            Text("Take Control of\nYour Inbox")
                .font(.system(size: 32, weight: .bold))
                .multilineTextAlignment(.center)
                .foregroundColor(.primary)

            // Description
            Text("Swipe through unwanted subscriptions and reclaim your email in minutes.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
            Spacer()
        }
    }
}

// MARK: - How It Works Page

/// Second onboarding page explaining the swipe mechanics
struct HowItWorksPage: View {

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Title
            Text("Simple as Swipe")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.primary)

            // Instructions
            VStack(spacing: 24) {
                // Swipe left instruction
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.red.opacity(0.1))
                            .frame(width: 60, height: 60)

                        Image(systemName: "arrow.left")
                            .font(.title2)
                            .foregroundColor(.red)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Swipe Left")
                            .font(.headline)
                            .foregroundColor(.primary)

                        Text("Unsubscribe from unwanted emails")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }

                // Swipe right instruction
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.1))
                            .frame(width: 60, height: 60)

                        Image(systemName: "arrow.right")
                            .font(.title2)
                            .foregroundColor(.green)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Swipe Right")
                            .font(.headline)
                            .foregroundColor(.primary)

                        Text("Keep emails you want to receive")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
            }
            .padding(.horizontal, 40)

            Spacer()
            Spacer()
        }
    }
}

// MARK: - Previews

#Preview("Onboarding") {
    OnboardingView()
        .environmentObject(AuthViewModel())
}

#Preview("Onboarding - Dark") {
    OnboardingView()
        .environmentObject(AuthViewModel())
        .preferredColorScheme(.dark)
}

#Preview("Welcome Page") {
    WelcomePage()
}

#Preview("How It Works Page") {
    HowItWorksPage()
}

