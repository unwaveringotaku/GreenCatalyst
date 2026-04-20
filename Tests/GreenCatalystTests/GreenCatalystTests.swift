import Testing
@testable import GreenCatalyst

struct GreenCatalystTests {
    @Test
    func summaryStartsAtZeroWithoutEntriesOrCompletedNudges() {
        let calculator = CarbonCalculator()

        let summary = calculator.buildDailySummary(entries: [], completedNudges: [], target: 8.0)

        #expect(summary.totalKgCO2 == 0)
        #expect(summary.totalKgSaved == 0)
        #expect(summary.costSaved == 0)
        #expect(summary.pointsEarned == 0)
    }

    @Test
    func completedNudgesDriveSavedCostAndPoints() {
        let calculator = CarbonCalculator()
        let completedNudge = Nudge(
            title: "Cycle to work today",
            description: "Save carbon on your commute.",
            co2Saving: 2.4,
            costSaving: 3.5,
            category: .transport,
            priority: .high,
            icon: "bicycle"
        )
        completedNudge.markCompleted()

        let summary = calculator.buildDailySummary(
            entries: [
                CarbonEntry(category: .transport, kgCO2: 4.0),
                CarbonEntry(category: .transport, kgCO2: -2.4),
            ],
            completedNudges: [completedNudge],
            target: 8.0
        )

        #expect(summary.totalKgCO2 == 1.6)
        #expect(summary.totalKgSaved == 2.4)
        #expect(summary.costSaved == 3.5)
        #expect(summary.pointsEarned == 24)
        #expect(summary.nudgesActedOn == 1)
    }

    @Test
    func completedNudgeCanReduceNetEmissionsBelowZero() {
        let calculator = CarbonCalculator()
        let completedNudge = Nudge(
            title: "Switch to a plant-based lunch",
            description: "Save carbon at lunch.",
            co2Saving: 1.8,
            costSaving: 2.0,
            category: .food,
            priority: .medium,
            icon: "leaf.fill"
        )
        completedNudge.markCompleted()

        let summary = calculator.buildDailySummary(
            entries: [CarbonEntry(category: .food, kgCO2: -1.8)],
            completedNudges: [completedNudge],
            target: 8.0
        )

        #expect(summary.totalKgCO2 == -1.8)
        #expect(summary.progressPercent == 0.225)
    }

    @Test
    func habitStatsContributeToSavedMetricsAndCounts() {
        let calculator = CarbonCalculator()
        let habitStats = HabitCompletionStats(
            count: 2,
            totalKgSaved: 2.8,
            totalCostSaved: 3.8,
            pointsEarned: 28
        )

        let summary = calculator.buildDailySummary(
            entries: [CarbonEntry(category: .transport, kgCO2: -2.8)],
            completedNudges: [],
            habitStats: habitStats,
            target: 8.0
        )

        #expect(summary.totalKgCO2 == -2.8)
        #expect(summary.totalKgSaved == 2.8)
        #expect(summary.costSaved == 3.8)
        #expect(summary.pointsEarned == 28)
        #expect(summary.habitsCompleted == 2)
    }

    @Test @MainActor
    func completedNudgeMarksMatchingHabitWithoutDuplicatingPoints() async throws {
        let store = DataStore.makeInMemory()
        let homeViewModel = HomeViewModel(dataStore: store)

        for habit in Habit.defaults {
            try await store.saveHabit(habit)
        }

        let nudge = Nudge(
            title: "Cycle to work today",
            description: "Perfect cycling weather for your commute.",
            co2Saving: 2.4,
            costSaving: 3.5,
            category: .transport,
            priority: .high,
            icon: "bicycle"
        )

        homeViewModel.completeNudge(nudge)
        try await Task.sleep(for: .milliseconds(300))

        let habits = try await store.fetchHabits()
        let bikeHabit = try #require(habits.first(where: { $0.name == "Bike to Work" }))
        let profile = try await store.fetchUserProfile()
        let habitStats = try await store.fetchHabitCompletionStats(for: .today)

        #expect(bikeHabit.isCompletedToday)
        #expect(bikeHabit.streakCount == 1)
        #expect(profile.totalPoints == 24)
        #expect(habitStats.count == 1)
        #expect(habitStats.pointsEarned == 0)
    }
}
