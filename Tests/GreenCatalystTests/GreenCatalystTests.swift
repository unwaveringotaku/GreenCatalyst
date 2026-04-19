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
            entries: [CarbonEntry(category: .transport, kgCO2: 4.0)],
            completedNudges: [completedNudge],
            target: 8.0
        )

        #expect(summary.totalKgCO2 == 1.6)
        #expect(summary.totalKgSaved == 2.4)
        #expect(summary.costSaved == 3.5)
        #expect(summary.pointsEarned == 24)
        #expect(summary.nudgesActedOn == 1)
    }
}
