import XCTest
@testable import GreenCatalyst

final class GreenCatalystTests: XCTestCase {

    func testSummaryStartsAtZeroWithoutEntriesOrCompletedNudges() {
        let calculator = CarbonCalculator()

        let summary = calculator.buildDailySummary(entries: [], completedNudges: [], target: 8.0)

        XCTAssertEqual(summary.totalKgCO2, 0, accuracy: 0.0001)
        XCTAssertEqual(summary.totalKgSaved, 0, accuracy: 0.0001)
        XCTAssertEqual(summary.costSaved, 0, accuracy: 0.0001)
        XCTAssertEqual(summary.pointsEarned, 0)
    }

    func testCompletedNudgesDriveSavedCostAndPoints() {
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

        XCTAssertEqual(summary.totalKgCO2, 1.6, accuracy: 0.0001)
        XCTAssertEqual(summary.totalKgSaved, 2.4, accuracy: 0.0001)
        XCTAssertEqual(summary.costSaved, 3.5, accuracy: 0.0001)
        XCTAssertEqual(summary.pointsEarned, 24)
        XCTAssertEqual(summary.nudgesActedOn, 1)
    }

    func testCompletedNudgeCanReduceNetEmissionsBelowZero() {
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

        XCTAssertEqual(summary.totalKgCO2, -1.8, accuracy: 0.0001)
        XCTAssertEqual(summary.progressPercent, 0, accuracy: 0.0001)
    }

    func testCategoryBreakdownUsesNetCategoryTotals() throws {
        let calculator = CarbonCalculator()

        let summary = calculator.buildDailySummary(
            entries: [
                CarbonEntry(category: .transport, kgCO2: 4.0),
                CarbonEntry(category: .transport, kgCO2: -2.4),
                CarbonEntry(category: .food, kgCO2: -1.8),
            ],
            completedNudges: [],
            target: 8.0
        )

        XCTAssertEqual(summary.byCategory.count, 2)

        let transport = try XCTUnwrap(summary.byCategory.first { $0.category == .transport })
        let food = try XCTUnwrap(summary.byCategory.first { $0.category == .food })

        XCTAssertEqual(transport.kgCO2, 1.6, accuracy: 0.0001)
        XCTAssertEqual(food.kgCO2, -1.8, accuracy: 0.0001)
        XCTAssertEqual(transport.percentOfTotal, 1.6 / 3.4, accuracy: 0.0001)
        XCTAssertEqual(food.percentOfTotal, 1.8 / 3.4, accuracy: 0.0001)
    }

    func testHabitStatsContributeToSavedMetricsAndCounts() {
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

        XCTAssertEqual(summary.totalKgCO2, -2.8, accuracy: 0.0001)
        XCTAssertEqual(summary.totalKgSaved, 2.8, accuracy: 0.0001)
        XCTAssertEqual(summary.costSaved, 3.8, accuracy: 0.0001)
        XCTAssertEqual(summary.pointsEarned, 28)
        XCTAssertEqual(summary.habitsCompleted, 2)
    }

    func testRegionalTransportFactorsChangeByRegion() {
        let calculator = CarbonCalculator()

        let northAmerica = calculator.calculateTransport(mode: .car, distanceKm: 10, region: .northAmerica)
        let unitedKingdom = calculator.calculateTransport(mode: .car, distanceKm: 10, region: .unitedKingdom)

        XCTAssertGreaterThan(northAmerica, unitedKingdom)
        XCTAssertEqual(unitedKingdom, 1.71, accuracy: 0.0001)
    }

    @MainActor
    func testFetchHabitsSeedsDefaultsOnFirstAccess() async throws {
        let store = DataStore.makeInMemory()

        let habits = try await store.fetchHabits()

        XCTAssertEqual(habits.count, Habit.defaults.count)
        XCTAssertTrue(habits.contains { $0.name == "Bike to Work" })
    }

    @MainActor
    func testCompletedNudgeMarksMatchingHabitWithoutDuplicatingPoints() async throws {
        let store = DataStore.makeInMemory()
        let homeViewModel = HomeViewModel(dataStore: store)

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
        guard let bikeHabit = habits.first(where: { $0.name == "Bike to Work" }) else {
            XCTFail("Expected Bike to Work habit")
            return
        }

        let profile = try await store.fetchUserProfile()
        let habitStats = try await store.fetchHabitCompletionStats(for: .today)

        XCTAssertTrue(bikeHabit.isCompletedToday)
        XCTAssertEqual(bikeHabit.streakCount, 1)
        XCTAssertEqual(profile.totalPoints, 24)
        XCTAssertEqual(habitStats.count, 1)
        XCTAssertEqual(habitStats.pointsEarned, 0)
    }
}
