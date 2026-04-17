import SwiftUI
import SwiftData
import UserNotifications

// MARK: - GreenCatalystApp

@main
struct GreenCatalystApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    GreenCatalystShortcuts.updateAppShortcutParameters()
                }
        }
    }
}

// MARK: - AppDelegate

final class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Register notification categories
        Task {
            await NotificationManager.shared.checkAuthorizationStatus()
        }
        return true
    }

    func application(
        _ application: UIApplication,
        continue userActivity: NSUserActivity,
        restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
    ) -> Bool {
        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Clear badge on becoming active
        UNUserNotificationCenter.current().setBadgeCount(0)
        // Sync HealthKit data in background
        Task {
            await HealthKitManager.shared.requestAuthorization()
        }
    }
}
