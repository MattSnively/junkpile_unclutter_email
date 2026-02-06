import Foundation
import UserNotifications

/// NotificationService manages local notification permissions and scheduling.
/// Singleton pattern matching APIService/KeychainService.
/// Handles streak reminder notifications that encourage daily engagement.
final class NotificationService {

    // MARK: - Singleton

    /// Shared singleton instance
    static let shared = NotificationService()

    /// Private initializer to enforce singleton usage
    private init() {}

    // MARK: - Notification Identifiers

    /// Identifier for the daily streak reminder notification.
    /// Using a fixed identifier ensures each schedule call replaces the previous
    /// one rather than stacking duplicate notifications.
    private let streakReminderIdentifier = "streakReminder"

    // MARK: - Authorization

    /// Requests notification authorization from the user.
    /// Returns true if the user grants permission, false if denied.
    /// - Returns: Whether notification permission was granted
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            return false
        }
    }

    /// Checks the current notification authorization status.
    /// Use this to verify permission state matches UI toggle state
    /// (catches cases where user revokes permission in iOS Settings).
    /// - Returns: The current UNAuthorizationStatus
    func checkAuthorizationStatus() async -> UNAuthorizationStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus
    }

    // MARK: - Streak Reminder

    /// Schedules a daily streak reminder notification at the specified hour.
    /// Uses `UNCalendarNotificationTrigger` to fire at the user's chosen time.
    /// The fixed identifier ensures idempotent replacement — calling this
    /// multiple times just reschedules, never stacks.
    /// - Parameters:
    ///   - hour: The hour (0-23) to fire the notification
    ///   - currentStreak: The user's current streak count for the notification body
    func scheduleStreakReminder(hour: Int, currentStreak: Int) {
        // Build the notification content
        let content = UNMutableNotificationContent()
        content.title = "Don't break your streak!"
        content.body = "You haven't swiped today. Keep your \(currentStreak)-day streak alive!"
        content.sound = .default

        // Create a calendar trigger at the specified hour, repeating daily
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents,
            repeats: true
        )

        // Create the request with fixed identifier for idempotent replacement
        let request = UNNotificationRequest(
            identifier: streakReminderIdentifier,
            content: content,
            trigger: trigger
        )

        // Schedule — replaces any existing notification with the same identifier
        UNUserNotificationCenter.current().add(request)
    }

    /// Cancels all pending notifications scheduled by this app.
    /// Called when the user disables streak notifications in Settings.
    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
