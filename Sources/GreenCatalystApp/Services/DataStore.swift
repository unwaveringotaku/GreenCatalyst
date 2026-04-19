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

// MARK: - DataStore

/// SwiftData-backed persistence layer.
/// All public methods are async and throw, enabling easy unit testing via mock injection.
@MainActor
final class DataStore {

    static let shared = DataStore()

    private var modelContainer: ModelContainer?
    private var modelContext: ModelContext?

    init() {
        do {
            let schema = Schema([
                CarbonEntry.self,
                Habit.self,
                Nudge.self,
                UserProfile.self,
            ])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            let container = try ModelContainer(for: schema, configurations: [config])
            modelContainer = container
            modelContext = ModelContext(container)
        } catch {
            print("[DataStore] Failed to create ModelContainer: \(error)")
        }
    }

    /// In-memory store for testing
    static func makeInMemory() -> DataStore {
        let store = DataStore()
        // Re-init with in-memory config
        do {
            let schema = Schema([CarbonEntry.self, Habit.self, Nudge.self, UserProfile.self])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            let container = try ModelContainer(for: schema, configurations: [config])
            store.modelContainer = container
            store.modelContext = ModelContext(container)
        } catch {
            print("[DataStore] Failed to create in-memory container: \(error)")
        }
        return store
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
}
