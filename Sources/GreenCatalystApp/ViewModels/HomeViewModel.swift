import Foundation
import Observation
import Combine

// MARK: - HomeViewModel

/// Drives the Home tab: today's carbon ring, active nudges, and quick-log.
@MainActor
@Observable
final class HomeViewModel {

    // MARK: - Published State

    var todaySummary: ImpactSummary = .empty()
    var activeNudges: [Nudge] = []
    var recentEntries: [CarbonEntry] = []
    var userProfile: UserProfile = UserProfile()
    var isLoading: Bool = false
    var errorMessage: String? = nil
    var showAddEntrySheet: Bool = false
    var selectedNudge: Nudge? = nil

    // MARK: - Dependencies

    private let dataStore: DataStore
    private let carbonCalculator: CarbonCalculator
    private let notificationManager: NotificationManager
    private let healthKitManager: HealthKitManager

    // MARK: - Init

    init(
        dataStore: DataStore = .shared,
        carbonCalculator: CarbonCalculator = CarbonCalculator(),
        notificationManager: NotificationManager = .shared,
        healthKitManager: HealthKitManager = .shared
    ) {
        self.dataStore = dataStore
        self.carbonCalculator = carbonCalculator
        self.notificationManager = notificationManager
        self.healthKitManager = healthKitManager
    }

    // MARK: - Lifecycle

    func onAppear() {
        Task { await loadData() }
    }

    // MARK: - Data Loading

    @MainActor
    func loadData() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let fetchedEntries = try await dataStore.fetchTodaysEntries()
            let fetchedNudges = try await dataStore.fetchActiveNudges()
            let completedNudges = try await dataStore.fetchCompletedNudges(for: .today)
            let fetchedProfile = try await dataStore.fetchUserProfile()

            recentEntries = fetchedEntries
            activeNudges = fetchedNudges
                .filter { $0.isActive }
                .sorted { $0.priority > $1.priority }
            userProfile = fetchedProfile
            todaySummary = carbonCalculator.buildDailySummary(
                entries: fetchedEntries,
                completedNudges: completedNudges,
                target: fetchedProfile.targetKgPerDay
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Quick Log

    func logCarbonEntry(
        category: CarbonCategory,
        kgCO2: Double,
        source: CarbonSource = .manual,
        notes: String? = nil
    ) {
        let entry = CarbonEntry(
            category: category,
            kgCO2: kgCO2,
            source: source,
            notes: notes
        )
        Task {
            do {
                try await dataStore.saveEntry(entry)
                await loadData()
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription }
            }
        }
    }

    func logTransportEntry(mode: TransportMode, distanceKm: Double) {
        let kg = carbonCalculator.calculateTransport(mode: mode, distanceKm: distanceKm)
        let entry = CarbonEntry(
            category: .transport,
            kgCO2: kg,
            source: .manual,
            transportMode: mode,
            distanceKm: distanceKm
        )
        Task {
            do {
                try await dataStore.saveEntry(entry)
                await loadData()
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription }
            }
        }
    }

    // MARK: - Nudge Actions

    func completeNudge(_ nudge: Nudge) {
        nudge.markCompleted()
        userProfile.addPoints(Int(nudge.co2Saving * 10))
        let savingsEntry = CarbonEntry(
            category: nudge.category,
            kgCO2: -nudge.co2Saving,
            source: .manual,
            notes: "Completed nudge: \(nudge.title)"
        )
        Task {
            do {
                try await dataStore.saveEntry(savingsEntry)
                try await dataStore.saveNudge(nudge)
                try await dataStore.saveProfile(userProfile)
                await loadData()
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription }
            }
        }
    }

    func dismissNudge(_ nudge: Nudge) {
        nudge.dismiss()
        Task {
            try? await dataStore.saveNudge(nudge)
            await loadData()
        }
    }

    // MARK: - HealthKit Sync

    func syncHealthKitData() {
        Task {
            do {
                await healthKitManager.requestAuthorization()
                let inferredEntries = try await healthKitManager.inferCarbonEntries(for: .now)
                for entry in inferredEntries {
                    try await dataStore.saveEntry(entry)
                }
                await loadData()
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription }
            }
        }
    }

    // MARK: - Onboarding Permissions

    func requestAllPermissions() async {
        await healthKitManager.requestAuthorization()
        await notificationManager.requestAuthorization()
    }
}
