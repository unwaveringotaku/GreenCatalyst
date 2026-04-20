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
        // Create default profile on first launch
        let profile = UserProfile()
        context.insert(profile)
        try context.save()
        return profile
    }

    func saveProfile(_ profile: UserProfile) async throws {
        context.insert(profile)
        do {
            try context.save()
        } catch {
            throw DataStoreError.saveFailed(error)
        }
    }

    // MARK: - CarbonEntry

    func fetchTodaysEntries() async throws -> [CarbonEntry] {
        let today = Calendar.current.startOfDay(for: .now)
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        var descriptor = FetchDescriptor<CarbonEntry>(
            predicate: #Predicate<CarbonEntry> { entry in
                entry.date >= today && entry.date < tomorrow
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 100
        do {
            return try context.fetch(descriptor)
        } catch {
            throw DataStoreError.fetchFailed(error)
        }
    }

    func fetchEntries(for period: SummaryPeriod) async throws -> [CarbonEntry] {
        let start = startDate(for: period)
        let end = Date.now
        var descriptor = FetchDescriptor<CarbonEntry>(
            predicate: #Predicate<CarbonEntry> { entry in
                entry.date >= start && entry.date <= end
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 1000
        do {
            return try context.fetch(descriptor)
        } catch {
            throw DataStoreError.fetchFailed(error)
        }
    }

    func saveEntry(_ entry: CarbonEntry) async throws {
        context.insert(entry)
        do {
            try context.save()
        } catch {
            throw DataStoreError.saveFailed(error)
        }
    }

    func deleteEntry(_ entry: CarbonEntry) async throws {
        context.delete(entry)
        do {
            try context.save()
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
            return try context.fetch(descriptor)
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
            // Seed sample nudges if empty
            if nudges.isEmpty {
                for nudge in Nudge.sampleNudges {
                    context.insert(nudge)
                    nudges.append(nudge)
                }
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

    func saveNudge(_ nudge: Nudge) async throws {
        context.insert(nudge)
        do {
            try context.save()
        } catch {
            throw DataStoreError.saveFailed(error)
        }
    }

    // MARK: - Synchronous Variants (for AppIntents)

    func saveEntrySync(_ entry: CarbonEntry) {
        context.insert(entry)
    }

    func saveContext() throws {
        try context.save()
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
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
