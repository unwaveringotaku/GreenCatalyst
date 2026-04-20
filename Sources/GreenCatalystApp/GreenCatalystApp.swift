import SwiftUI
import SwiftData
import UserNotifications
import WatchConnectivity

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
            _ = WatchSyncManager.shared
            let locationManager = LocationManager.shared
            locationManager.refreshAuthorizationStatus()
            locationManager.startPassiveMonitoring()
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
        LocationManager.shared.startPassiveMonitoring()
    }
}

// MARK: - WatchSyncManager

@MainActor
final class WatchSyncManager: NSObject {
    static let shared = WatchSyncManager()

    private override init() {
        super.init()

        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func pushLatestSnapshot() async {
        guard WCSession.isSupported() else { return }
        guard WCSession.default.activationState == .activated else { return }

        let payload = await buildPayload()

        if WCSession.default.isReachable {
            WCSession.default.sendMessage(payload, replyHandler: nil)
        } else {
            try? WCSession.default.updateApplicationContext(payload)
        }
    }

    private func buildPayload() async -> [String: Any] {
        do {
            let store = DataStore.shared
            let entries = try await store.fetchTodaysEntries()
            let habits = try await store.fetchHabits()
            let nudges = try await store.fetchActiveNudges()
            let profile = try await store.fetchUserProfile()

            let totalKg = entries.reduce(0.0) { $0 + $1.kgCO2 }
            let topNudge = nudges.sorted { $0.priority > $1.priority }.first
            let topStreak = habits.map(\.streakCount).max() ?? 0

            return [
                "kgCO2Today": totalKg,
                "targetKg": profile.targetKgPerDay,
                "topStreak": topStreak,
                "topNudge": topNudge?.title ?? "",
                "topNudgeCO2": topNudge?.co2Saving ?? 0,
            ]
        } catch {
            return [:]
        }
    }
}

extension WatchSyncManager: WCSessionDelegate {
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {}

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard message["requestUpdate"] as? Bool == true else { return }

        Task { @MainActor in
            await pushLatestSnapshot()
        }
    }
}
