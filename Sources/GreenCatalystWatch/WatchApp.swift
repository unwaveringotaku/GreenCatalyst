import SwiftUI
import WatchKit
import WatchConnectivity

// MARK: - WatchApp

@main
struct WatchApp: App {

    @WKApplicationDelegateAdaptor(WatchAppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            WatchHomeView()
        }
    }
}

// MARK: - WatchAppDelegate

final class WatchAppDelegate: NSObject, WKApplicationDelegate {

    override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    func applicationDidFinishLaunching() {
        // Schedule background refresh for data sync
        WKApplication.shared().scheduleBackgroundRefresh(
            withPreferredDate: Date(timeIntervalSinceNow: 60 * 15),
            userInfo: nil
        ) { _ in }
    }
}

// MARK: - WCSessionDelegate

extension WatchAppDelegate: WCSessionDelegate {

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        let kgCO2 = message["kgCO2Today"] as? Double
        let targetKg = message["targetKg"] as? Double
        let streak = message["topStreak"] as? Int
        let nudge = message["topNudge"] as? String
        let nudgeCO2 = message["topNudgeCO2"] as? Double
        Task { @MainActor in
            if let kgCO2 { WatchDataStore.shared.kgCO2Today = kgCO2 }
            if let targetKg { WatchDataStore.shared.targetKg = targetKg }
            if let streak { WatchDataStore.shared.topStreak = streak }
            if let nudge { WatchDataStore.shared.topNudgeTitle = nudge.isEmpty ? nil : nudge }
            if let nudgeCO2 { WatchDataStore.shared.topNudgeCO2 = nudgeCO2 }
            if kgCO2 != nil || targetKg != nil || streak != nil || nudge != nil || nudgeCO2 != nil {
                WatchDataStore.shared.lastSyncDate = .now
            }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        let kgCO2 = applicationContext["kgCO2Today"] as? Double
        let targetKg = applicationContext["targetKg"] as? Double
        let streak = applicationContext["topStreak"] as? Int
        let nudge = applicationContext["topNudge"] as? String
        let nudgeCO2 = applicationContext["topNudgeCO2"] as? Double
        Task { @MainActor in
            if let kgCO2 { WatchDataStore.shared.kgCO2Today = kgCO2 }
            if let targetKg { WatchDataStore.shared.targetKg = targetKg }
            if let streak { WatchDataStore.shared.topStreak = streak }
            if let nudge { WatchDataStore.shared.topNudgeTitle = nudge.isEmpty ? nil : nudge }
            if let nudgeCO2 { WatchDataStore.shared.topNudgeCO2 = nudgeCO2 }
            if kgCO2 != nil || targetKg != nil || streak != nil || nudge != nil || nudgeCO2 != nil {
                WatchDataStore.shared.lastSyncDate = .now
            }
        }
    }
}

// MARK: - WatchDataStore

/// Lightweight in-memory/UserDefaults store for Watch.
@MainActor @Observable
final class WatchDataStore {
    static let shared = WatchDataStore()

    var kgCO2Today: Double {
        get { UserDefaults.standard.double(forKey: "watch_kgCO2Today") }
        set { UserDefaults.standard.set(newValue, forKey: "watch_kgCO2Today") }
    }
    var targetKg: Double {
        get {
            let value = UserDefaults.standard.double(forKey: "watch_targetKg")
            return value > 0 ? value : 8.0
        }
        set { UserDefaults.standard.set(newValue, forKey: "watch_targetKg") }
    }
    var topStreak: Int {
        get { UserDefaults.standard.integer(forKey: "watch_topStreak") }
        set { UserDefaults.standard.set(newValue, forKey: "watch_topStreak") }
    }
    var topNudgeTitle: String? {
        get { UserDefaults.standard.string(forKey: "watch_topNudge") }
        set { UserDefaults.standard.set(newValue, forKey: "watch_topNudge") }
    }
    var topNudgeCO2: Double {
        get { UserDefaults.standard.double(forKey: "watch_topNudgeCO2") }
        set { UserDefaults.standard.set(newValue, forKey: "watch_topNudgeCO2") }
    }
    var lastSyncDate: Date? {
        get { UserDefaults.standard.object(forKey: "watch_lastSyncDate") as? Date }
        set { UserDefaults.standard.set(newValue, forKey: "watch_lastSyncDate") }
    }

    var progress: Double {
        guard targetKg > 0 else { return 0 }
        return min(max(0, kgCO2Today) / targetKg, 1.0)
    }

    var isUnderTarget: Bool { kgCO2Today <= targetKg }
    var hasSyncedData: Bool { lastSyncDate != nil }

    func sendUpdateToPhone() {
        guard WCSession.default.isReachable else { return }
        WCSession.default.sendMessage(["requestUpdate": true], replyHandler: nil)
    }
}
