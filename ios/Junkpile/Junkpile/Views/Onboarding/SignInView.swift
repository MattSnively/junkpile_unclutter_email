import SwiftUI
import AuthenticationServices

/// SignInView presents both Sign in with Apple and Sign in with Google options.
/// Replaces GoogleSignInView as the primary sign-in sheet in the onboarding flow.
///
/// Per Apple Guideline 4.8, Sign in with Apple must have equal or greater
/// prominence than third-party sign-in options — so the Apple button appears first.
struct SignInView: View {

    // MARK: - Environment

    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                // Header
                headerSection

                // Sign-in buttons
                signInButtons

                // Privacy note
                privacyNote

                Spacer()
                Spacer()
            }
            .padding(.horizontal, 24)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(.primary)
                    }
                    .accessibilityLabel("Close")
                    .accessibilityHint("Dismiss sign-in sheet")
                }
            }
            .alert("Sign In Error", isPresented: showingError) {
                Button("OK") {
                    authViewModel.clearError()
                }
            } message: {
                Text(authViewModel.errorMessage ?? "An unknown error occurred")
            }
            .onChange(of: authViewModel.authState) { _, authState in
                // Dismiss the sign-in sheet when authentication succeeds
                if authState == .authenticated {
                    dismiss()
                }
            }
        }
    }

    // MARK: - Components

    /// Header with icon and title
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "envelope.badge.shield.half.filled")
                .font(.system(size: 60))
                .foregroundStyle(.primary, .red)

            Text("Sign In to Junkpile")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.primary)

            Text("Sign in with Apple to get started, then connect Gmail in the next step")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    /// Sign-in button stack — Apple first (per Guideline 4.8), then Google.
    /// Each button has an explanatory caption underneath.
    private var signInButtons: some View {
        VStack(spacing: 16) {
            // Sign in with Apple — primary, per Apple Guideline 4.8
            VStack(spacing: 6) {
                appleSignInButton

                Text("Recommended — sign in with Apple, then connect Gmail")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            // "or" divider
            divider

            // Sign in with Google — secondary
            VStack(spacing: 6) {
                googleSignInButton

                Text("Signs in and connects Gmail in one step")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    /// Apple Sign-In button using SwiftUI's SignInWithAppleButton.
    /// Uses .black style in light mode, .white style in dark mode for contrast.
    private var appleSignInButton: some View {
        SignInWithAppleButton(.signIn) { request in
            // Configure the Apple Sign-In request
            request.requestedScopes = [.email, .fullName]
        } onCompletion: { _ in
            // The actual sign-in is handled by AppleAuthService via AuthViewModel.
            // SignInWithAppleButton's onCompletion is for the UI dismissal only —
            // we trigger the full flow via the Task below.
        }
        // We use a custom button approach instead since SignInWithAppleButton
        // doesn't integrate well with our async auth flow.
        .hidden() // Hide the default button
        .frame(height: 0)
        .overlay {
            // Custom Apple-styled button that triggers our async flow
            Button {
                Task {
                    await authViewModel.signInWithApple()
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "apple.logo")
                        .font(.title3)

                    Text(authViewModel.isLoading && authViewModel.authProvider == nil
                         ? "Signing in..." : "Sign in with Apple")
                        .font(.headline)
                }
                .foregroundColor(colorScheme == .dark ? .black : .white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(colorScheme == .dark ? Color.white : Color.black)
                .cornerRadius(12)
            }
            .disabled(authViewModel.isLoading)
            .opacity(authViewModel.isLoading ? 0.6 : 1.0)
            .accessibilityLabel(authViewModel.isLoading ? "Signing in" : "Sign in with Apple")
            .accessibilityHint("Sign in using your Apple ID")
        }
    }

    /// "or" divider between Apple and Google buttons
    private var divider: some View {
        HStack(spacing: 16) {
            Rectangle()
                .fill(Theme.separator)
                .frame(height: 1)

            Text("or")
                .font(.subheadline.weight(.medium))
                .foregroundColor(.secondary)

            Rectangle()
                .fill(Theme.separator)
                .frame(height: 1)
        }
    }

    /// Google sign-in button — styled per Google brand guidelines
    private var googleSignInButton: some View {
        Button {
            Task {
                await authViewModel.signInWithGoogle(from: authViewModel.keyWindow)
            }
        } label: {
            HStack(spacing: 12) {
                // Official Google "G" logo from asset catalog
                Image("GoogleG")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)

                Text(authViewModel.isLoading ? "Signing in..." : "Sign in with Google")
                    .font(.headline)
            }
            .foregroundColor(.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Theme.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Theme.googleBorder, lineWidth: 1.5)
            )
            .cornerRadius(12)
            .shadow(color: Theme.shadow(opacity: 0.08), radius: 2, x: 0, y: 1)
        }
        .disabled(authViewModel.isLoading)
        .opacity(authViewModel.isLoading ? 0.6 : 1.0)
        .accessibilityLabel(authViewModel.isLoading ? "Signing in" : "Sign in with Google")
        .accessibilityHint("Sign in with your Google account and connect Gmail")
    }

    /// Privacy note explaining what we access
    private var privacyNote: some View {
        VStack(spacing: 8) {
            Text("We never store your email content or share your data.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(16)
        .background(Theme.subtleFill)
        .cornerRadius(12)
    }

    // MARK: - Computed Properties

    /// Binding for showing error alert
    private var showingError: Binding<Bool> {
        Binding(
            get: { authViewModel.errorMessage != nil },
            set: { if !$0 { authViewModel.clearError() } }
        )
    }
}

// MARK: - Previews

#Preview("Sign In View") {
    SignInView()
        .environmentObject(AuthViewModel())
}

#Preview("Sign In View - Dark") {
    SignInView()
        .environmentObject(AuthViewModel())
        .preferredColorScheme(.dark)
}
