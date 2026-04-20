import Foundation
import Observation
import UserNotifications

// MARK: - HabitsViewModel

/// Drives the Habits tab: habit list, streak management, and reminders.
@MainActor
@Observable
final class HabitsViewModel {

    // MARK: - State

    var habits: [Habit] = []
    var selectedCategory: CarbonCategory? = nil
    var showAddHabitSheet: Bool = false
    var habitToEdit: Habit? = nil
    var isLoading: Bool = false
    var errorMessage: String? = nil

    // MARK: - Derived

    var filteredHabits: [Habit] {
        if let cat = selectedCategory {
            return habits.filter { $0.category == cat }
        }
        return habits
    }

    var activeHabits: [Habit] {
        filteredHabits.filter { $0.isActive }
    }

    var totalStreakDays: Int {
        habits.map { $0.streakCount }.reduce(0, +)
    }

    var totalCO2Saved: Double {
        habits.map { $0.totalCO2Saved }.reduce(0, +)
    }

    var totalCostSaved: Double {
        habits.map { $0.totalCostSaved }.reduce(0, +)
    }

    // MARK: - Dependencies

    private let dataStore: DataStore
    private let notificationManager: NotificationManager

    // MARK: - Init

    init(
        dataStore: DataStore = .shared,
        notificationManager: NotificationManager = .shared
    ) {
        self.dataStore = dataStore
        self.notificationManager = notificationManager
    }

    // MARK: - Lifecycle

    func onAppear() {
        Task { await loadHabits() }
    }

    // MARK: - Data Loading

    @MainActor
    func loadHabits() async {
        isLoading = true
        defer { isLoading = false }
        do {
            habits = try await dataStore.fetchHabits()
            if habits.isEmpty {
                // Seed defaults on first launch
                let defaults = Habit.defaults
                for habit in defaults {
                    try await dataStore.saveHabit(habit)
                }
                habits = defaults
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Habit Actions

    func completeHabit(_ habit: Habit) {
        guard !habit.isCompletedToday else { return }
        habit.markCompleted(source: .habit)

        let pointsEarned = Int((max(0, habit.co2PerAction) * 10).rounded())

        Task {
            do {
                let profile = try await dataStore.fetchUserProfile()
                profile.addPoints(pointsEarned)

                try await dataStore.saveHabit(habit)

                // Log as a carbon entry too
                let entry = CarbonEntry(
                    category: habit.category,
                    kgCO2: -habit.co2PerAction,   // negative = saved
                    source: .manual,
                    notes: "Habit: \(habit.name)"
                )
                try await dataStore.saveEntry(entry)
                try await dataStore.saveProfile(profile)

                NotificationCenter.default.post(name: .habitDataDidChange, object: nil)
                await loadHabits()
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription }
            }
        }
    }

    func addHabit(_ habit: Habit) {
        Task {
            do {
                try await dataStore.saveHabit(habit)
                if let reminder = habit.reminderTime {
                    try await notificationManager.scheduleHabitReminder(habit: habit, at: reminder)
                }
                await loadHabits()
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription }
            }
        }
    }

    func deleteHabit(_ habit: Habit) {
        Task {
            do {
                try await dataStore.deleteHabit(habit)
                await notificationManager.cancelHabitReminder(habitId: habit.id)
                await loadHabits()
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription }
            }
        }
    }

    func toggleHabitActive(_ habit: Habit) {
        habit.isActive.toggle()
        Task {
            try? await dataStore.saveHabit(habit)
            await loadHabits()
        }
    }

    func updateReminder(for habit: Habit, time: Date?) async throws {
        habit.reminderTime = time
        try await dataStore.saveHabit(habit)
        if let time = time {
            try await notificationManager.scheduleHabitReminder(habit: habit, at: time)
        } else {
            await notificationManager.cancelHabitReminder(habitId: habit.id)
        }
    }
}
