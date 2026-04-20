import Foundation
import Observation

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
    private let locationManager: LocationManager
    private let watchSyncManager: WatchSyncManager?

    // MARK: - Init

    init(
        dataStore: DataStore = .shared,
        carbonCalculator: CarbonCalculator = CarbonCalculator(),
        notificationManager: NotificationManager = .shared,
        healthKitManager: HealthKitManager = .shared,
        locationManager: LocationManager = .shared,
        watchSyncManager: WatchSyncManager? = .shared
    ) {
        self.dataStore = dataStore
        self.carbonCalculator = carbonCalculator
        self.notificationManager = notificationManager
        self.healthKitManager = healthKitManager
        self.locationManager = locationManager
        self.watchSyncManager = watchSyncManager
    }

    // MARK: - Lifecycle

    func onAppear() {
        Task {
            locationManager.startPassiveMonitoring()
            await loadData()
        }
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
            let habitStats = try await dataStore.fetchHabitCompletionStats(for: .today)
            let fetchedProfile = try await dataStore.fetchUserProfile()

            recentEntries = fetchedEntries
            activeNudges = fetchedNudges
                .filter { $0.isActive }
                .sorted { $0.priority > $1.priority }
            userProfile = fetchedProfile
            todaySummary = carbonCalculator.buildDailySummary(
                entries: fetchedEntries,
                completedNudges: completedNudges,
                habitStats: habitStats,
                target: fetchedProfile.targetKgPerDay,
                region: fetchedProfile.resolvedRegion
            )
            await watchSyncManager?.pushLatestSnapshot()
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
        saveAndReload(entry)
    }

    func logTransportEntry(mode: TransportMode, distanceKm: Double, notes: String? = nil) {
        let kg = carbonCalculator.calculateTransport(
            mode: mode,
            distanceKm: distanceKm,
            region: userProfile.resolvedRegion
        )
        let entry = CarbonEntry(
            category: .transport,
            kgCO2: kg,
            source: .manual,
            notes: notes,
            transportMode: mode,
            distanceKm: distanceKm
        )
        saveAndReload(entry)
    }

    func logFoodEntry(type: CarbonCalculator.FoodType, grams: Double, notes: String? = nil) {
        let entry = CarbonEntry(
            category: .food,
            kgCO2: carbonCalculator.calculateFood(
                type: type,
                grams: grams,
                region: userProfile.resolvedRegion
            ),
            source: .manual,
            notes: notes ?? "\(type.rawValue) (\(Int(grams.rounded())) g)"
        )
        saveAndReload(entry)
    }

    func logEnergyEntry(source: CarbonCalculator.EnergySource, kWh: Double, notes: String? = nil) {
        let kgCO2: Double
        switch source {
        case .electricity:
            kgCO2 = carbonCalculator.calculateElectricity(kWh: kWh, region: userProfile.resolvedRegion)
        case .gas:
            kgCO2 = carbonCalculator.calculateGas(kWh: kWh, region: userProfile.resolvedRegion)
        }

        let entry = CarbonEntry(
            category: .energy,
            kgCO2: kgCO2,
            source: .manual,
            notes: notes ?? "\(source.rawValue) (\(String(format: "%.1f", kWh)) kWh)"
        )
        saveAndReload(entry)
    }

    func logShoppingEntry(category: CarbonCalculator.ProductCategory, spendAmount: Double, notes: String? = nil) {
        let entry = CarbonEntry(
            category: .shopping,
            kgCO2: carbonCalculator.calculateShopping(
                category: category,
                spendAmount: spendAmount,
                region: userProfile.resolvedRegion
            ),
            source: .manual,
            notes: notes ?? "\(category.rawValue) purchase"
        )
        saveAndReload(entry)
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
                let linkedHabit = try await matchingHabit(for: nudge)
                if let linkedHabit {
                    linkedHabit.markCompleted(source: .nudge)
                    try await dataStore.saveHabit(linkedHabit)
                }

                try await dataStore.saveEntry(savingsEntry)
                try await dataStore.saveNudge(nudge)
                try await dataStore.saveProfile(userProfile)
                if linkedHabit != nil {
                    NotificationCenter.default.post(name: .habitDataDidChange, object: nil)
                }
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
                let profile = try await dataStore.fetchUserProfile()
                let inferredEntries = try await healthKitManager.inferCarbonEntries(
                    for: .now,
                    region: profile.resolvedRegion
                )
                for entry in inferredEntries {
                    try await dataStore.saveEntryIfNeeded(entry)
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
        locationManager.requestPassiveCommutePermission()
    }

    func handleCompletedNudgeNotification(idString: String) {
        guard let id = UUID(uuidString: idString) else { return }

        Task {
            do {
                guard let nudge = try await dataStore.fetchNudge(id: id), !nudge.isCompleted else { return }
                await MainActor.run {
                    completeNudge(nudge)
                }
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription }
            }
        }
    }

    func handleHabitLogNotification(idString: String) {
        guard let id = UUID(uuidString: idString) else { return }

        Task {
            do {
                guard let habit = try await dataStore.fetchHabit(id: id), !habit.isCompletedToday else { return }
                let pointsEarned = Int((max(0, habit.co2PerAction) * 10).rounded())
                let profile = try await dataStore.fetchUserProfile()
                profile.addPoints(pointsEarned)

                habit.markCompleted(source: .habit)
                try await dataStore.saveHabit(habit)

                let entry = CarbonEntry(
                    category: habit.category,
                    kgCO2: -habit.co2PerAction,
                    source: .manual,
                    notes: "Habit: \(habit.name)"
                )
                try await dataStore.saveEntry(entry)
                try await dataStore.saveProfile(profile)

                NotificationCenter.default.post(name: .habitDataDidChange, object: nil)
                await loadData()
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription }
            }
        }
    }

    private func matchingHabit(for nudge: Nudge) async throws -> Habit? {
        let habits = try await dataStore.fetchHabits()
        let candidate = habits
            .filter { $0.isActive && !$0.isCompletedToday && $0.category == nudge.category }
            .max { lhs, rhs in
                matchScore(for: lhs, against: nudge) < matchScore(for: rhs, against: nudge)
            }

        guard let candidate, matchScore(for: candidate, against: nudge) >= 3 else {
            return nil
        }

        return candidate
    }

    private func matchScore(for habit: Habit, against nudge: Nudge) -> Int {
        var score = 0

        if habit.icon == nudge.icon {
            score += 4
        }

        if abs(habit.co2PerAction - nudge.co2Saving) < 0.05 {
            score += 3
        }

        let habitTerms = normalizedTerms(in: "\(habit.name) \(habit.habitDescription)")
        let nudgeTerms = normalizedTerms(in: "\(nudge.title) \(nudge.nudgeDescription)")
        score += min(2, habitTerms.intersection(nudgeTerms).count)

        return score
    }

    private func normalizedTerms(in text: String) -> Set<String> {
        let stopWords: Set<String> = [
            "a", "an", "and", "at", "for", "from", "in", "instead", "its",
            "it", "of", "on", "or", "the", "this", "to", "today", "vs", "your"
        ]

        return Set(
            text
                .lowercased()
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { !$0.isEmpty }
                .map { term in
                    switch term {
                    case "bike", "biking", "bicycle":
                        return "cycle"
                    case "commute":
                        return "work"
                    default:
                        return term
                    }
                }
                .filter { !stopWords.contains($0) }
        )
    }

    private func saveAndReload(_ entry: CarbonEntry) {
        Task {
            do {
                try await dataStore.saveEntry(entry)
                await loadData()
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription }
            }
        }
    }
}
