import SwiftUI

/// SettingsView provides account management, notification preferences, and app information.
struct SettingsView: View {

    // MARK: - Environment

    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var gamificationViewModel: GamificationViewModel

    // MARK: - State

    /// Whether streak notifications are enabled
    @AppStorage("streakNotificationsEnabled") private var streakNotificationsEnabled = true

    /// Preferred notification time (hour)
    @AppStorage("notificationHour") private var notificationHour = 20 // 8 PM default

    /// Whether to confirm before signing out
    @State private var showingSignOutConfirmation = false

    /// Whether to show data export options
    @State private var showingDataExport = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            List {
                // Account section
                accountSection

                // Notifications section
                notificationsSection

                // Data section
                dataSection

                // About section
                aboutSection

                // Sign out section
                signOutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .confirmationDialog(
                "Sign Out",
                isPresented: $showingSignOutConfirmation,
                titleVisibility: .visible
            ) {
                Button("Sign Out", role: .destructive) {
                    Task {
                        await authViewModel.signOut()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to sign out? Your progress is saved and will be here when you return.")
            }
        }
    }

    // MARK: - Sections

    /// Account information section
    private var accountSection: some View {
        Section {
            // Profile row
            HStack(spacing: 12) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(Color.black)
                        .frame(width: 50, height: 50)

                    Text(authViewModel.userInitial)
                        .font(.title3.bold())
                        .foregroundColor(.white)
                }

                // User info
                VStack(alignment: .leading, spacing: 4) {
                    Text(authViewModel.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)

                    if let email = authViewModel.userEmail {
                        Text(email)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()
            }
            .padding(.vertical, 4)

            // Gmail connection status
            HStack {
                Image(systemName: "envelope.fill")
                    .foregroundColor(.red)

                Text("Gmail")

                Spacer()

                Text("Connected")
                    .font(.caption)
                    .foregroundColor(.green)

                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.caption)
            }
        } header: {
            Text("Account")
        }
    }

    /// Notifications settings section
    private var notificationsSection: some View {
        Section {
            // Streak reminder toggle
            Toggle(isOn: $streakNotificationsEnabled) {
                HStack {
                    Image(systemName: "flame.fill")
                        .foregroundColor(.orange)

                    Text("Streak Reminders")
                }
            }
            .tint(.black)

            // Notification time picker (only if enabled)
            if streakNotificationsEnabled {
                HStack {
                    Text("Reminder Time")

                    Spacer()

                    Picker("", selection: $notificationHour) {
                        ForEach(6..<23) { hour in
                            Text(formatHour(hour))
                                .tag(hour)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
        } header: {
            Text("Notifications")
        } footer: {
            Text("Get a daily reminder to maintain your streak")
        }
    }

    /// Data and privacy section
    private var dataSection: some View {
        Section {
            // View privacy policy
            Link(destination: URL(string: "https://junkpile.app/privacy")!) {
                HStack {
                    Image(systemName: "hand.raised.fill")
                        .foregroundColor(.blue)

                    Text("Privacy Policy")

                    Spacer()

                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Data info
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)

                Text("Your Data")

                Spacer()
            }
            .contentShape(Rectangle())
            .onTapGesture {
                showingDataExport = true
            }
        } header: {
            Text("Data & Privacy")
        } footer: {
            Text("We only access email metadata to find unsubscribe links. We never read or store your email content.")
        }
        .sheet(isPresented: $showingDataExport) {
            DataInfoView()
        }
    }

    /// About app section
    private var aboutSection: some View {
        Section {
            // Version
            HStack {
                Text("Version")
                Spacer()
                Text("1.0.0")
                    .foregroundColor(.secondary)
            }

            // Rate app
            Link(destination: URL(string: "https://apps.apple.com/app/junkpile")!) {
                HStack {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)

                    Text("Rate Junkpile")

                    Spacer()

                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Feedback
            Link(destination: URL(string: "mailto:feedback@junkpile.app")!) {
                HStack {
                    Image(systemName: "envelope.fill")
                        .foregroundColor(.blue)

                    Text("Send Feedback")

                    Spacer()

                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        } header: {
            Text("About")
        }
    }

    /// Sign out section
    private var signOutSection: some View {
        Section {
            Button(role: .destructive) {
                showingSignOutConfirmation = true
            } label: {
                HStack {
                    Spacer()
                    Text("Sign Out")
                    Spacer()
                }
            }
        }
    }

    // MARK: - Helpers

    /// Formats an hour as a 12-hour time string.
    private func formatHour(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"

        var components = DateComponents()
        components.hour = hour

        if let date = Calendar.current.date(from: components) {
            return formatter.string(from: date)
        }
        return "\(hour):00"
    }
}

// MARK: - Data Info View

/// Sheet showing data privacy information
struct DataInfoView: View {

    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // What we access
                    VStack(alignment: .leading, spacing: 12) {
                        Label("What We Access", systemImage: "eye")
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 8) {
                            bulletPoint("Email sender names")
                            bulletPoint("Email subject lines")
                            bulletPoint("Unsubscribe links in emails")
                            bulletPoint("Email read status (to mark as read)")
                        }
                    }

                    Divider()

                    // What we don't access
                    VStack(alignment: .leading, spacing: 12) {
                        Label("What We Don't Access", systemImage: "eye.slash")
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 8) {
                            bulletPoint("Full email content/body")
                            bulletPoint("Attachments")
                            bulletPoint("Contacts or calendar")
                            bulletPoint("Any other Google services")
                        }
                    }

                    Divider()

                    // Data storage
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Data Storage", systemImage: "externaldrive")
                            .font(.headline)

                        Text("Your gamification progress (points, achievements, streaks) is stored locally on your device using secure iOS storage. Your swipe decisions are synced to our server to process unsubscribe requests.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Divider()

                    // Token security
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Token Security", systemImage: "lock.shield")
                            .font(.headline)

                        Text("Your Google authentication tokens are stored securely in iOS Keychain, the same secure storage used by iOS for passwords and other sensitive credentials.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
            }
            .navigationTitle("Your Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    /// Creates a bullet point text row
    private func bulletPoint(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .foregroundColor(.secondary)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Previews

#Preview("Settings View") {
    let authVM = AuthViewModel()
    authVM.isAuthenticated = true

    return SettingsView()
        .environmentObject(authVM)
        .environmentObject(GamificationViewModel())
}

#Preview("Data Info View") {
    DataInfoView()
}
