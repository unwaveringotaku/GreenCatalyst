import Foundation
import UserNotifications

// MARK: - NotificationCategory

enum NotificationCategory: String {
    case nudge         = "NUDGE"
    case habitReminder = "HABIT_REMINDER"
    case weeklyReport  = "WEEKLY_REPORT"
    case streakAlert   = "STREAK_ALERT"
}

// MARK: - NotificationManager

/// Centralised push-notification service.
/// Handles permission requests, scheduling, and cancellation.
@MainActor
final class NotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {

    static let shared = NotificationManager()
    private let center = UNUserNotificationCenter.current()

    @Published var isAuthorized: Bool = false

    override init() {
        super.init()
        center.delegate = self
    }

    // MARK: - Authorization

    func requestAuthorization() async {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            isAuthorized = granted
            if granted { registerCategories() }
        } catch {
            isAuthorized = false
        }
    }

    func checkAuthorizationStatus() async {
        let settings = await center.notificationSettings()
        isAuthorized = (settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional)
    }

    // MARK: - Categories & Actions

    private func registerCategories() {
        // Nudge category: Done + Dismiss actions
        let doneAction    = UNNotificationAction(identifier: "NUDGE_DONE",    title: "Done ✅", options: [.foreground])
        let dismissAction = UNNotificationAction(identifier: "NUDGE_DISMISS", title: "Dismiss",  options: [.destructive])
        let nudgeCategory = UNNotificationCategory(
            identifier: NotificationCategory.nudge.rawValue,
            actions: [doneAction, dismissAction],
            intentIdentifiers: [],
            options: []
        )

        // Habit reminder: Log It + Skip actions
        let logAction  = UNNotificationAction(identifier: "HABIT_LOG",  title: "Log It 🌿", options: [.foreground])
        let skipAction = UNNotificationAction(identifier: "HABIT_SKIP", title: "Skip",      options: [])
        let habitCategory = UNNotificationCategory(
            identifier: NotificationCategory.habitReminder.rawValue,
            actions: [logAction, skipAction],
            intentIdentifiers: [],
            options: []
        )

        center.setNotificationCategories([nudgeCategory, habitCategory])
    }

    // MARK: - Nudge Notifications

    func scheduleNudgeNotification(nudge: Nudge, at date: Date) throws {
        guard isAuthorized else { return }
        let content = UNMutableNotificationContent()
        content.title = nudge.title
        content.body  = nudge.nudgeDescription
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.nudge.rawValue
        content.userInfo = ["nudgeId": nudge.id.uuidString]
        content.badge = 1

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: "nudge-\(nudge.id.uuidString)", content: content, trigger: trigger)

        Task {
            try await center.add(request)
        }
    }

    // MARK: - Habit Reminders

    func scheduleHabitReminder(habit: Habit, at time: Date) async throws {
        guard isAuthorized else { return }
        let content = UNMutableNotificationContent()
        content.title = "Time for: \(habit.name) 🌿"
        content.body  = "Complete it now and save \(String(format: "%.1f", habit.co2PerAction)) kg CO₂"
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.habitReminder.rawValue
        content.userInfo = ["habitId": habit.id.uuidString]

        let components = Calendar.current.dateComponents([.hour, .minute], from: time)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: "habit-\(habit.id.uuidString)",
            content: content,
            trigger: trigger
        )
        try await center.add(request)
    }

    func cancelHabitReminder(habitId: UUID) async {
        center.removePendingNotificationRequests(withIdentifiers: ["habit-\(habitId.uuidString)"])
    }

    // MARK: - Weekly Report

    func scheduleWeeklyReport() async throws {
        guard isAuthorized else { return }
        let content = UNMutableNotificationContent()
        content.title = "Your weekly carbon report is ready 📊"
        content.body  = "See how much CO₂ you saved this week vs your target."
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.weeklyReport.rawValue

        var components = DateComponents()
        components.weekday = 1   // Sunday
        components.hour    = 9
        components.minute  = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: "weekly-report", content: content, trigger: trigger)
        try await center.add(request)
    }

    // MARK: - Streak Alerts

    func scheduleStreakAlert(habit: Habit) async throws {
        guard isAuthorized, habit.streakCount > 0 else { return }
        let content = UNMutableNotificationContent()
        content.title = "Don't break your streak! 🔥"
        content.body  = "\(habit.name) – \(habit.streakCount) day streak at risk. Complete it today."
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.streakAlert.rawValue
        content.userInfo = ["habitId": habit.id.uuidString]

        // Fire at 20:00 same day
        var components = Calendar.current.dateComponents([.year, .month, .day], from: .now)
        components.hour   = 20
        components.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: "streak-\(habit.id.uuidString)",
            content: content,
            trigger: trigger
        )
        try await center.add(request)
    }

    // MARK: - Utilities

    func cancelAll() {
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }

    func pendingNotifications() async -> [UNNotificationRequest] {
        await center.pendingNotificationRequests()
    }

    // MARK: - UNUserNotificationCenterDelegate

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        switch response.actionIdentifier {
        case "NUDGE_DONE":
            if let idStr = userInfo["nudgeId"] as? String {
                NotificationCenter.default.post(name: .nudgeCompleted, object: idStr)
            }
        case "HABIT_LOG":
            if let idStr = userInfo["habitId"] as? String {
                NotificationCenter.default.post(name: .habitLogRequested, object: idStr)
            }
        default:
            break
        }
        completionHandler()
    }
}

// MARK: - NSNotification Names

extension Notification.Name {
    static let nudgeCompleted    = Notification.Name("GreenCatalyst.nudgeCompleted")
    static let habitLogRequested = Notification.Name("GreenCatalyst.habitLogRequested")
}
