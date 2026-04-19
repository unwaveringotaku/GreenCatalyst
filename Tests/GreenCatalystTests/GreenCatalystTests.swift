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
}
