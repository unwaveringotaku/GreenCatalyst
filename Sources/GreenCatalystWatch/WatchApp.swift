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
        // Extract values on the calling thread before crossing isolation boundary
        let kgCO2 = message["kgCO2Today"] as? Double
        let streak = message["topStreak"] as? Int
        let nudge = message["topNudge"] as? String
        Task { @MainActor in
            if let kgCO2 { WatchDataStore.shared.kgCO2Today = kgCO2 }
            if let streak { WatchDataStore.shared.topStreak = streak }
            if let nudge { WatchDataStore.shared.topNudgeTitle = nudge }
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
        get { max(1, UserDefaults.standard.double(forKey: "watch_targetKg")) == 0 ? 8.0 : UserDefaults.standard.double(forKey: "watch_targetKg") }
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

    var progress: Double {
        guard targetKg > 0 else { return 0 }
        return min(kgCO2Today / targetKg, 1.0)
    }

    var isUnderTarget: Bool { kgCO2Today <= targetKg }

    // Seed with demo data if empty
    init() {
        if kgCO2Today == 0 {
            kgCO2Today = 4.6
            targetKg = 8.0
            topStreak = 5
            topNudgeTitle = "Cycle to work today"
            topNudgeCO2 = 2.4
        }
    }

    func sendUpdateToPhone() {
        guard WCSession.default.isReachable else { return }
        WCSession.default.sendMessage(["requestUpdate": true], replyHandler: nil)
    }
}
