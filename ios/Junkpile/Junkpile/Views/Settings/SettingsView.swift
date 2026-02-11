import SwiftUI
import UserNotifications

/// SettingsView provides account management, notification preferences, and app information.
struct SettingsView: View {

    // MARK: - Environment

    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var gamificationViewModel: GamificationViewModel

    // MARK: - State

    /// Whether streak notifications are enabled — defaults to false since no
    /// permission is requested until the user explicitly toggles this on.
    @AppStorage("streakNotificationsEnabled") private var streakNotificationsEnabled = false

    /// Preferred notification time (hour)
    @AppStorage("notificationHour") private var notificationHour = 20 // 8 PM default

    /// Whether the user's notification permission has been denied at the iOS level.
    /// Used to show a "Notifications disabled in Settings" footer.
    @State private var isNotificationDenied = false

    /// Whether to show the "Open Settings" alert when permission is denied
    @State private var showingNotificationDeniedAlert = false

    /// Whether to confirm before signing out
    @State private var showingSignOutConfirmation = false

    /// Whether to show data export options
    @State private var showingDataExport = false

    /// Current Gmail connection status, checked dynamically on view appear
    @State private var gmailStatus: GmailConnectionStatus = .checking

    /// Whether to show the delete account confirmation dialog
    @State private var showingDeleteAccountConfirmation = false

    /// Whether account deletion is in progress
    @State private var isDeletingAccount = false

    /// Error message from a failed delete account attempt
    @State private var deleteAccountError: String?

    /// Whether to show the disclaimer sheet
    @State private var showingDisclaimer = false

    // MARK: - Gmail Connection Status

    /// Represents the current state of the Gmail OAuth connection.
    /// Checked on SettingsView appear to replace the previously hardcoded "Connected" label.
    enum GmailConnectionStatus {
        case checking       // Network call in progress
        case connected      // Token is valid, Gmail accessible
        case disconnected   // Token invalid or Gmail not configured
        case error(String)  // Network error during check
    }

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
                        .fill(Theme.solidFill)
                        .frame(width: 50, height: 50)

                    Text(authViewModel.userInitial)
                        .font(.title3.bold())
                        .foregroundColor(Theme.solidFillForeground)
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

            // Gmail connection status — dynamically validated on view appear.
            // Replaces the previously hardcoded "Connected" label so users
            // can see if their token expired or Gmail disconnected.
            HStack {
                Image(systemName: "envelope.fill")
                    .foregroundColor(.red)

                Text("Gmail")

                Spacer()

                // Dynamic status indicator based on actual token validation
                gmailStatusView
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Gmail connection: \(gmailStatusAccessibilityLabel)")
            .task {
                await checkGmailConnection()
            }
        } header: {
            Text("Account")
        }
    }

    /// Notifications settings section — full permission flow:
    /// Toggle ON → check permission → request if needed → schedule or show alert
    /// Toggle OFF → cancel pending notifications
    private var notificationsSection: some View {
        Section {
            // Streak reminder toggle with custom binding that intercepts changes
            // to handle the notification permission flow
            Toggle(isOn: notificationToggleBinding) {
                HStack {
                    Image(systemName: "flame.fill")
                        .foregroundColor(.orange)

                    Text("Streak Reminders")
                }
            }
            .tint(.primary)

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
                // When the user changes the notification hour, reschedule at the new time
                .onChange(of: notificationHour) { _, newHour in
                    NotificationService.shared.scheduleStreakReminder(
                        hour: newHour,
                        currentStreak: gamificationViewModel.currentStreak
                    )
                }
            }
        } header: {
            Text("Notifications")
        } footer: {
            if isNotificationDenied {
                Text("Notifications disabled in Settings. Tap the toggle to open Settings.")
            } else {
                Text("Get a daily reminder to maintain your streak")
            }
        }
        // Verify permission state matches toggle on view appear — catches
        // the case where the user revoked permission in iOS Settings
        .task {
            await syncNotificationToggleWithPermission()
        }
        // Alert shown when user tries to enable notifications but iOS permission is denied
        .alert("Notifications Disabled", isPresented: $showingNotificationDeniedAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Notifications are disabled for Junkpile. Open Settings to enable them.")
        }
    }

    /// Custom binding for the notification toggle that intercepts changes
    /// to handle the full permission request flow.
    private var notificationToggleBinding: Binding<Bool> {
        Binding(
            get: { streakNotificationsEnabled },
            set: { newValue in
                if newValue {
                    // User is turning ON notifications — check and request permission
                    Task {
                        await handleNotificationToggleOn()
                    }
                } else {
                    // User is turning OFF notifications — cancel pending notifications
                    streakNotificationsEnabled = false
                    NotificationService.shared.cancelAllNotifications()
                }
            }
        )
    }

    /// Handles the notification toggle being turned ON.
    /// Checks current permission status and either requests, schedules, or alerts.
    private func handleNotificationToggleOn() async {
        let status = await NotificationService.shared.checkAuthorizationStatus()

        switch status {
        case .notDetermined:
            // First time — request authorization from the user
            let granted = await NotificationService.shared.requestAuthorization()
            if granted {
                streakNotificationsEnabled = true
                isNotificationDenied = false
                NotificationService.shared.scheduleStreakReminder(
                    hour: notificationHour,
                    currentStreak: gamificationViewModel.currentStreak
                )
            } else {
                // User denied the permission prompt — keep toggle OFF
                streakNotificationsEnabled = false
                isNotificationDenied = true
            }

        case .authorized, .provisional, .ephemeral:
            // Already have permission — schedule immediately
            streakNotificationsEnabled = true
            isNotificationDenied = false
            NotificationService.shared.scheduleStreakReminder(
                hour: notificationHour,
                currentStreak: gamificationViewModel.currentStreak
            )

        case .denied:
            // Permission previously denied at the iOS level — show Settings alert
            streakNotificationsEnabled = false
            isNotificationDenied = true
            showingNotificationDeniedAlert = true

        @unknown default:
            streakNotificationsEnabled = false
        }
    }

    /// Verifies that the notification toggle matches the actual iOS permission state.
    /// Catches cases where the user revoked permission in iOS Settings after enabling
    /// the toggle in Junkpile.
    private func syncNotificationToggleWithPermission() async {
        let status = await NotificationService.shared.checkAuthorizationStatus()

        switch status {
        case .denied:
            // Permission revoked in Settings — flip toggle OFF and show footer
            if streakNotificationsEnabled {
                streakNotificationsEnabled = false
                NotificationService.shared.cancelAllNotifications()
            }
            isNotificationDenied = true

        case .authorized, .provisional, .ephemeral:
            isNotificationDenied = false

        case .notDetermined:
            // Never asked — ensure toggle is OFF
            if streakNotificationsEnabled {
                streakNotificationsEnabled = false
            }
            isNotificationDenied = false

        @unknown default:
            break
        }
    }

    /// Data and privacy section
    private var dataSection: some View {
        Section {
            // View privacy policy — safe URL unwrap to prevent crash
            if let privacyURL = URL(string: "https://junkpile.app/privacy") {
                Link(destination: privacyURL) {
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

            // Delete Account — requires double confirmation to prevent accidents.
            // Calls the server to delete all data, then clears local storage.
            Button(role: .destructive) {
                showingDeleteAccountConfirmation = true
            } label: {
                HStack {
                    if isDeletingAccount {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                    Image(systemName: "trash.fill")
                        .foregroundColor(.red)

                    Text("Delete Account")
                        .foregroundColor(.red)

                    Spacer()
                }
            }
            .disabled(isDeletingAccount)
        } header: {
            Text("Data & Privacy")
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                Text("We only access email metadata to find unsubscribe links. We never read or store your email content.")
                if let deleteError = deleteAccountError {
                    Text(deleteError)
                        .foregroundColor(.red)
                }
            }
        }
        .sheet(isPresented: $showingDataExport) {
            DataInfoView()
        }
        .confirmationDialog(
            "Delete Account",
            isPresented: $showingDeleteAccountConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Everything", role: .destructive) {
                Task {
                    await performAccountDeletion()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete your account and all associated data. This action cannot be undone.")
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

            // Rate app — safe URL unwrap to prevent crash
            if let rateURL = URL(string: "https://apps.apple.com/app/junkpile") {
                Link(destination: rateURL) {
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
            }

            // Disclaimer — opens a sheet with legal disclaimers
            Button {
                showingDisclaimer = true
            } label: {
                HStack {
                    Image(systemName: "doc.text")
                        .foregroundColor(.secondary)

                    Text("Disclaimer")
                        .foregroundColor(.primary)

                    Spacer()
                }
            }

            // Feedback — safe URL unwrap to prevent crash
            if let feedbackURL = URL(string: "mailto:feedback@junkpile.app") {
                Link(destination: feedbackURL) {
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
            }
        } header: {
            Text("About")
        }
        .sheet(isPresented: $showingDisclaimer) {
            DisclaimerView()
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

    // MARK: - Gmail Status

    /// Renders the appropriate status indicator for the Gmail connection.
    /// Shows a spinner while checking, green checkmark when connected,
    /// a "Reconnect" button when disconnected, or a warning on error.
    @ViewBuilder
    private var gmailStatusView: some View {
        switch gmailStatus {
        case .checking:
            ProgressView()
                .scaleEffect(0.7)
            Text("Checking...")
                .font(.caption)
                .foregroundColor(.secondary)

        case .connected:
            Text("Connected")
                .font(.caption)
                .foregroundColor(.green)
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.caption)

        case .disconnected:
            Button("Reconnect") {
                Task {
                    await authViewModel.signIn(from: authViewModel.keyWindow)
                    // Re-check after sign-in attempt
                    await checkGmailConnection()
                }
            }
            .font(.caption.bold())
            .foregroundColor(.red)

        case .error(let message):
            Text(message)
                .font(.caption)
                .foregroundColor(.orange)
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
                .font(.caption)
        }
    }

    /// Readable status string for VoiceOver based on current Gmail connection state
    private var gmailStatusAccessibilityLabel: String {
        switch gmailStatus {
        case .checking: return "Checking"
        case .connected: return "Connected"
        case .disconnected: return "Disconnected. Double tap to reconnect."
        case .error(let message): return "Error: \(message)"
        }
    }

    /// Checks the actual Gmail connection status by validating the stored OAuth token.
    /// Called on view appear to provide real-time connection feedback.
    private func checkGmailConnection() async {
        gmailStatus = .checking

        // First check if credentials exist locally
        guard KeychainService.shared.hasStoredCredentials() else {
            gmailStatus = .disconnected
            return
        }

        // Validate the token with the server
        do {
            let response = try await APIService.shared.validateToken()
            gmailStatus = response.valid ? .connected : .disconnected
        } catch let error as APIError {
            // Distinguish auth failures (disconnected) from network errors
            switch error {
            case .authenticationRequired, .tokenExpired:
                gmailStatus = .disconnected
            case .networkError:
                gmailStatus = .error("Offline")
            default:
                gmailStatus = .error("Check failed")
            }
        } catch {
            gmailStatus = .error("Check failed")
        }
    }

    // MARK: - Account Deletion

    /// Performs the full account deletion flow:
    /// 1. Calls the server to delete all server-side data and revoke tokens
    /// 2. Clears local keychain credentials
    /// 3. Signs the user out, returning to the onboarding screen
    /// Falls back gracefully if the API call fails (shows error, keeps account).
    private func performAccountDeletion() async {
        isDeletingAccount = true
        deleteAccountError = nil

        do {
            let response = try await APIService.shared.deleteAccount()
            if response.success {
                // Clear local credentials and sign out
                KeychainService.shared.clearAllAuthData()
                await authViewModel.signOut()
            } else {
                deleteAccountError = response.error ?? "Account deletion failed. Please try again."
            }
        } catch {
            deleteAccountError = "Could not reach the server. Please check your connection and try again."
        }

        isDeletingAccount = false
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
    authVM.authState = .authenticated

    return SettingsView()
        .environmentObject(authVM)
        .environmentObject(GamificationViewModel())
}

#Preview("Data Info View") {
    DataInfoView()
}
