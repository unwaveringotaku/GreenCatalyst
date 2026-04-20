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
}
