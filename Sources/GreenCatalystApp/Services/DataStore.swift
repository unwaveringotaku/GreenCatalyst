import Foundation
import SwiftData

// MARK: - DataStoreError

enum DataStoreError: LocalizedError {
    case profileNotFound
    case saveFailed(Error)
    case fetchFailed(Error)
    case deleteFailed(Error)

    var errorDescription: String? {
        switch self {
        case .profileNotFound:    return "User profile not found. Please restart the app."
        case .saveFailed(let e):  return "Save failed: \(e.localizedDescription)"
        case .fetchFailed(let e): return "Fetch failed: \(e.localizedDescription)"
        case .deleteFailed(let e): return "Delete failed: \(e.localizedDescription)"
        }
    }
}

struct HabitCompletionStats: Equatable {
    let count: Int
    let totalKgSaved: Double
    let totalCostSaved: Double
    let pointsEarned: Int

    static let zero = HabitCompletionStats(
        count: 0,
        totalKgSaved: 0,
        totalCostSaved: 0,
        pointsEarned: 0
    )
}

extension Notification.Name {
    static let habitDataDidChange = Notification.Name("habitDataDidChange")
    static let carbonDataDidChange = Notification.Name("GreenCatalyst.carbonDataDidChange")
}

// MARK: - ProfileSnapshot

/// Lightweight local backup used to recover the profile after schema resets.
struct ProfileSnapshot: Codable {
    let name: String
    let email: String?
    let dietaryPreference: DietaryPreference
    let targetKgPerDay: Double
    let regionPreference: CarbonRegionPreference
    let hasCompletedOnboarding: Bool
    let permissions: GrantedPermissions
    let notificationEnabled: Bool
    let totalPoints: Int
    let level: Int
    let badges: [String]

    func makeProfile() -> UserProfile {
        let profile = UserProfile(
            name: name,
            email: email,
            targetKgPerDay: targetKgPerDay,
            dietaryPreference: dietaryPreference,
            regionPreference: regionPreference
        )
        profile.hasCompletedOnboarding = hasCompletedOnboarding
        profile.permissions = permissions
        profile.notificationEnabled = notificationEnabled
        profile.totalPoints = totalPoints
        profile.level = level
        profile.badges = badges
        return profile
    }
}

// MARK: - ProfileSnapshotStore

@MainActor
final class ProfileSnapshotStore {

    static let shared = ProfileSnapshotStore()

    private let defaults: UserDefaults
    private let snapshotKey = "GreenCatalyst.profileSnapshot"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func backupProfile(_ profile: UserProfile) {
        let snapshot = ProfileSnapshot(
            name: profile.name,
            email: profile.email,
            dietaryPreference: profile.dietaryPreference,
            targetKgPerDay: profile.targetKgPerDay,
            regionPreference: profile.regionPreference,
            hasCompletedOnboarding: profile.hasCompletedOnboarding,
            permissions: profile.permissions,
            notificationEnabled: profile.notificationEnabled,
            totalPoints: profile.totalPoints,
            level: profile.level,
            badges: profile.badges
        )

        if let data = try? JSONEncoder().encode(snapshot) {
            defaults.set(data, forKey: snapshotKey)
        }
    }

    func restoreProfile() -> ProfileSnapshot? {
        guard let data = defaults.data(forKey: snapshotKey) else { return nil }
        return try? JSONDecoder().decode(ProfileSnapshot.self, from: data)
    }

    func clear() {
        defaults.removeObject(forKey: snapshotKey)
    }
}

// MARK: - DataStore

/// SwiftData-backed persistence layer.
/// All public methods are async and throw, enabling easy unit testing via mock injection.
@MainActor
final class DataStore {

    static let shared = DataStore()

    private var modelContainer: ModelContainer?
    private var modelContext: ModelContext?

    private enum StorageMode {
        case persistent
        case inMemory
    }

    private init(storageMode: StorageMode = .persistent) {
        let schema = Self.makeSchema()

        switch storageMode {
        case .persistent:
            if configurePersistentStore(schema: schema) {
                return
            }

            do {
                try Self.resetPersistentStoreFiles()
                if configurePersistentStore(schema: schema) {
                    print("[DataStore] Recreated persistent store after reset.")
                    return
                }
            } catch {
                print("[DataStore] Failed to reset persistent store: \(error)")
            }

            print("[DataStore] Falling back to in-memory store.")
            configureInMemoryStore(schema: schema)

        case .inMemory:
            configureInMemoryStore(schema: schema)
        }
    }

    /// In-memory store for testing
    static func makeInMemory() -> DataStore {
        DataStore(storageMode: .inMemory)
    }

    private var context: ModelContext {
        guard let ctx = modelContext else {
            fatalError("[DataStore] ModelContext not initialised")
        }
        return ctx
    }

    // MARK: - UserProfile

    func fetchUserProfile() async throws -> UserProfile {
        let descriptor = FetchDescriptor<UserProfile>()
        let results = try context.fetch(descriptor)
        if let profile = results.first { return profile }
        // Restore the last known profile after a schema reset if available.
        let profile = ProfileSnapshotStore.shared.restoreProfile()?.makeProfile() ?? UserProfile()
        context.insert(profile)
        try context.save()
        return profile
    }

    func saveProfile(_ profile: UserProfile) async throws {
        context.insert(profile)
        do {
            try context.save()
            ProfileSnapshotStore.shared.backupProfile(profile)
        } catch {
            throw DataStoreError.saveFailed(error)
        }
    }

    // MARK: - CarbonEntry

    func fetchTodaysEntries() async throws -> [CarbonEntry] {
        let today = Calendar.current.startOfDay(for: .now)
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        return try await fetchEntries(from: today, to: tomorrow, inclusiveEnd: false)
    }

    func fetchEntries(from start: Date, to end: Date, inclusiveEnd: Bool = true) async throws -> [CarbonEntry] {
        do {
            return try fetchEntriesSync(from: start, to: end, inclusiveEnd: inclusiveEnd)
        } catch {
            throw DataStoreError.fetchFailed(error)
        }
    }

    private func fetchEntriesSync(from start: Date, to end: Date, inclusiveEnd: Bool) throws -> [CarbonEntry] {
        var descriptor: FetchDescriptor<CarbonEntry>
        if inclusiveEnd {
            descriptor = FetchDescriptor<CarbonEntry>(
                predicate: #Predicate<CarbonEntry> { entry in
                    entry.date >= start && entry.date <= end
                },
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
        } else {
            descriptor = FetchDescriptor<CarbonEntry>(
                predicate: #Predicate<CarbonEntry> { entry in
                    entry.date >= start && entry.date < end
                },
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
        }
        descriptor.fetchLimit = 1000
        return try context.fetch(descriptor)
    }

    func fetchEntries(for period: SummaryPeriod) async throws -> [CarbonEntry] {
        let start = startDate(for: period)
        let end = Date.now
        return try await fetchEntries(from: start, to: end)
    }

    func saveEntry(_ entry: CarbonEntry) async throws {
        context.insert(entry)
        do {
            try context.save()
            NotificationCenter.default.post(name: .carbonDataDidChange, object: nil)
        } catch {
            throw DataStoreError.saveFailed(error)
        }
    }

    @discardableResult
    func saveEntryIfNeeded(_ entry: CarbonEntry) async throws -> Bool {
        if try existingEntry(matching: entry) != nil {
            return false
        }

        try await saveEntry(entry)
        return true
    }

    func deleteEntry(_ entry: CarbonEntry) async throws {
        context.delete(entry)
        do {
            try context.save()
            NotificationCenter.default.post(name: .carbonDataDidChange, object: nil)
        } catch {
            throw DataStoreError.deleteFailed(error)
        }
    }

    // MARK: - Habits

    func fetchHabits() async throws -> [Habit] {
        let descriptor = FetchDescriptor<Habit>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        do {
            var habits = try context.fetch(descriptor)
            if habits.isEmpty {
                habits = Habit.defaults
                for habit in habits {
                    context.insert(habit)
                }
                try context.save()
                NotificationCenter.default.post(name: .habitDataDidChange, object: nil)
            }
            return habits
        } catch {
            throw DataStoreError.fetchFailed(error)
        }
    }

    func saveHabit(_ habit: Habit) async throws {
        context.insert(habit)
        do {
            try context.save()
        } catch {
            throw DataStoreError.saveFailed(error)
        }
    }

    func deleteHabit(_ habit: Habit) async throws {
        context.delete(habit)
        do {
            try context.save()
        } catch {
            throw DataStoreError.deleteFailed(error)
        }
    }

    func fetchHabitCompletionStats(for period: SummaryPeriod) async throws -> HabitCompletionStats {
        let start = startDate(for: period)
        let end = Date.now
        return try await fetchHabitCompletionStats(from: start, to: end)
    }

    func fetchHabitCompletionStats(from start: Date, to end: Date) async throws -> HabitCompletionStats {
        try await calculateHabitCompletionStats(from: start, to: end)
    }

    private func calculateHabitCompletionStats(from start: Date, to end: Date) async throws -> HabitCompletionStats {
        do {
            let habits = try await fetchHabits()
            var count = 0
            var totalKgSaved = 0.0
            var totalCostSaved = 0.0
            var pointsEarned = 0

            for habit in habits {
                let indexedCompletions = habit.completionDates.enumerated().filter { _, completionDate in
                    completionDate >= start && completionDate <= end
                }

                guard !indexedCompletions.isEmpty else { continue }

                count += indexedCompletions.count

                for (index, _) in indexedCompletions {
                    let source = HabitCompletionSource(
                        rawValue: habit.completionSourceTags[safe: index] ?? HabitCompletionSource.habit.rawValue
                    ) ?? .habit

                    guard source == .habit else { continue }

                    totalKgSaved += max(0, habit.co2PerAction)
                    totalCostSaved += max(0, habit.costPerAction)
                    pointsEarned += Int((max(0, habit.co2PerAction) * 10).rounded())
                }
            }

            return HabitCompletionStats(
                count: count,
                totalKgSaved: totalKgSaved,
                totalCostSaved: totalCostSaved,
                pointsEarned: pointsEarned
            )
        } catch {
            throw DataStoreError.fetchFailed(error)
        }
    }

    // MARK: - Nudges

    func fetchActiveNudges() async throws -> [Nudge] {
        let now = Date.now
        var descriptor = FetchDescriptor<Nudge>(
            predicate: #Predicate<Nudge> { nudge in
                nudge.isCompleted == false && nudge.isDismissed == false
            },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 20
        do {
            var nudges = try context.fetch(descriptor)
            // Filter expired in-memory (complex predicate with optional Date)
            nudges = nudges.filter { nudge in
                guard let expiry = nudge.expiresAt else { return true }
                return expiry > now
            }
            var didRefreshExistingNudges = false
            for nudge in nudges where nudge.refreshForVersion102IfNeeded() {
                didRefreshExistingNudges = true
            }
            // Seed sample nudges if empty
            if nudges.isEmpty {
                for nudge in Nudge.sampleNudges {
                    context.insert(nudge)
                    nudges.append(nudge)
                }
                didRefreshExistingNudges = true
            }

            if didRefreshExistingNudges {
                try context.save()
            }
            return nudges
        } catch {
            throw DataStoreError.fetchFailed(error)
        }
    }

    func fetchCompletedNudges(for period: SummaryPeriod) async throws -> [Nudge] {
        let start = startDate(for: period)
        let end = Date.now
        return try await fetchCompletedNudges(from: start, to: end)
    }

    func fetchCompletedNudges(from start: Date, to end: Date) async throws -> [Nudge] {
        let descriptor = FetchDescriptor<Nudge>(
            predicate: #Predicate<Nudge> { nudge in
                nudge.isCompleted == true
            },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )

        do {
            return try context.fetch(descriptor).filter { nudge in
                guard let completedAt = nudge.completedAt else { return false }
                return completedAt >= start && completedAt <= end
            }
        } catch {
            throw DataStoreError.fetchFailed(error)
        }
    }

    func fetchNudge(id: UUID) async throws -> Nudge? {
        let descriptor = FetchDescriptor<Nudge>(
            predicate: #Predicate<Nudge> { nudge in
                nudge.id == id
            }
        )

        do {
            return try context.fetch(descriptor).first
        } catch {
            throw DataStoreError.fetchFailed(error)
        }
    }

    func saveNudge(_ nudge: Nudge) async throws {
        context.insert(nudge)
        do {
            try context.save()
        } catch {
            throw DataStoreError.saveFailed(error)
        }
    }

    func fetchHabit(id: UUID) async throws -> Habit? {
        let descriptor = FetchDescriptor<Habit>(
            predicate: #Predicate<Habit> { habit in
                habit.id == id
            }
        )

        do {
            return try context.fetch(descriptor).first
        } catch {
            throw DataStoreError.fetchFailed(error)
        }
    }

    // MARK: - Synchronous Variants (for AppIntents)

    func saveEntrySync(_ entry: CarbonEntry) {
        context.insert(entry)
    }

    func saveContext() throws {
        try context.save()
        NotificationCenter.default.post(name: .carbonDataDidChange, object: nil)
    }

    func fetchTodaysEntriesSync() throws -> [CarbonEntry] {
        let today = Calendar.current.startOfDay(for: .now)
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        var descriptor = FetchDescriptor<CarbonEntry>(
            predicate: #Predicate<CarbonEntry> { entry in
                entry.date >= today && entry.date < tomorrow
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 100
        return try context.fetch(descriptor)
    }

    func fetchUserProfileSync() throws -> UserProfile {
        let descriptor = FetchDescriptor<UserProfile>()
        let results = try context.fetch(descriptor)
        if let profile = results.first { return profile }
        let profile = UserProfile()
        context.insert(profile)
        try context.save()
        return profile
    }

    // MARK: - Helpers

    private func startDate(for period: SummaryPeriod) -> Date {
        let cal = Calendar.current
        let now = Date.now
        switch period {
        case .today:    return cal.startOfDay(for: now)
        case .week:     return cal.date(byAdding: .weekOfYear, value: -1, to: now)!
        case .month:    return cal.date(byAdding: .month, value: -1, to: now)!
        case .year:     return cal.date(byAdding: .year, value: -1, to: now)!
        case .allTime:  return cal.date(byAdding: .year, value: -10, to: now)!
        }
    }

    private static func makeSchema() -> Schema {
        Schema([
            CarbonEntry.self,
            Habit.self,
            Nudge.self,
            UserProfile.self,
        ])
    }

    @discardableResult
    private func configurePersistentStore(schema: Schema) -> Bool {
        do {
            let config = try Self.makePersistentConfiguration(schema: schema)
            let container = try ModelContainer(for: schema, configurations: [config])
            modelContainer = container
            modelContext = ModelContext(container)
            return true
        } catch {
            print("[DataStore] Failed to create persistent ModelContainer: \(error)")
            return false
        }
    }

    private func configureInMemoryStore(schema: Schema) {
        do {
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            let container = try ModelContainer(for: schema, configurations: [config])
            modelContainer = container
            modelContext = ModelContext(container)
        } catch {
            fatalError("[DataStore] Failed to create in-memory ModelContainer: \(error)")
        }
    }

    private static func makePersistentConfiguration(schema: Schema) throws -> ModelConfiguration {
        ModelConfiguration("GreenCatalyst", schema: schema, url: try persistentStoreURL())
    }

    private static func persistentStoreURL() throws -> URL {
        let fileManager = FileManager.default
        let appSupportURL = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let storeDirectoryURL = appSupportURL.appendingPathComponent("GreenCatalyst", isDirectory: true)

        if !fileManager.fileExists(atPath: storeDirectoryURL.path) {
            try fileManager.createDirectory(at: storeDirectoryURL, withIntermediateDirectories: true)
        }

        return storeDirectoryURL.appendingPathComponent("GreenCatalyst.store")
    }

    private static func resetPersistentStoreFiles() throws {
        let fileManager = FileManager.default
        let storeURL = try persistentStoreURL()
        let sidecarURLs = [
            storeURL,
            URL(fileURLWithPath: storeURL.path + "-shm"),
            URL(fileURLWithPath: storeURL.path + "-wal"),
        ]

        for url in sidecarURLs where fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }

    private func existingEntry(matching entry: CarbonEntry) throws -> CarbonEntry? {
        let start = entry.date.addingTimeInterval(-120)
        let end = entry.date.addingTimeInterval(120)
        let candidates = try fetchEntriesSync(from: start, to: end, inclusiveEnd: true)

        return candidates.first { candidate in
            candidate.category == entry.category &&
            candidate.source == entry.source &&
            abs(candidate.kgCO2 - entry.kgCO2) < 0.0001 &&
            candidate.notes == entry.notes &&
            candidate.transportMode == entry.transportMode &&
            normalizedDistance(candidate.distanceKm) == normalizedDistance(entry.distanceKm)
        }
    }

    private func normalizedDistance(_ distance: Double?) -> Int {
        guard let distance else { return -1 }
        return Int((distance * 100).rounded())
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
