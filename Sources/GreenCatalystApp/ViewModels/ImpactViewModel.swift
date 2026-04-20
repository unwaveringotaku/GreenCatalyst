import Foundation
import Observation

// MARK: - ImpactViewModel

/// Drives the Impact tab: historical charts, equivalencies, and period comparisons.
@MainActor
@Observable
final class ImpactViewModel {

    // MARK: - State

    var selectedPeriod: SummaryPeriod = .today
    var summary: ImpactSummary = .empty()
    var historicalEntries: [CarbonEntry] = []
    var weeklyTotals: [DailyTotal] = []
    var dailyTargetKg: Double = 8.0
    var isLoading: Bool = false
    var errorMessage: String? = nil

    // MARK: - Dependencies

    private let dataStore: DataStore
    private let carbonCalculator: CarbonCalculator

    // MARK: - Init

    init(
        dataStore: DataStore = .shared,
        carbonCalculator: CarbonCalculator = CarbonCalculator()
    ) {
        self.dataStore = dataStore
        self.carbonCalculator = carbonCalculator
    }

    // MARK: - Lifecycle

    func onAppear() {
        Task { await loadData() }
    }

    func onPeriodChanged() {
        Task { await loadData() }
    }

    // MARK: - Data Loading

    @MainActor
    func loadData() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let profile = try await dataStore.fetchUserProfile()
            let entries = try await dataStore.fetchEntries(for: selectedPeriod)
            let completedNudges = try await dataStore.fetchCompletedNudges(for: selectedPeriod)
            let habitStats = try await dataStore.fetchHabitCompletionStats(for: selectedPeriod)
            let previousRange = previousRange(for: selectedPeriod)
            let previousEntries = try await dataStore.fetchEntries(from: previousRange.start, to: previousRange.end)
            let previousCompletedNudges = try await dataStore.fetchCompletedNudges(from: previousRange.start, to: previousRange.end)
            let previousHabitStats = try await dataStore.fetchHabitCompletionStats(from: previousRange.start, to: previousRange.end)
            let previousSummary = carbonCalculator.buildSummary(
                entries: previousEntries,
                completedNudges: previousCompletedNudges,
                habitStats: previousHabitStats,
                period: selectedPeriod,
                target: profile.targetKgPerDay,
                region: profile.resolvedRegion
            )

            historicalEntries = entries
            dailyTargetKg = profile.targetKgPerDay
            summary = carbonCalculator.buildSummary(
                entries: entries,
                completedNudges: completedNudges,
                habitStats: habitStats,
                period: selectedPeriod,
                target: profile.targetKgPerDay,
                region: profile.resolvedRegion,
                vsLastPeriodDelta: entries.reduce(0.0) { $0 + $1.kgCO2 } - previousSummary.totalKgCO2
            )
            weeklyTotals = buildWeeklyTotals(from: entries)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Chart Data

    func buildWeeklyTotals(from entries: [CarbonEntry]) -> [DailyTotal] {
        let calendar = Calendar.current
        let today = Date.now
        return (0..<7).compactMap { daysAgo -> DailyTotal? in
            guard let date = calendar.date(byAdding: .day, value: -daysAgo, to: today) else { return nil }
            let dayEntries = entries.filter { calendar.isDate($0.date, inSameDayAs: date) }
            let total = dayEntries.reduce(0) { $0 + $1.kgCO2 }
            return DailyTotal(date: date, kgCO2: total)
        }.reversed()
    }

    // MARK: - Export

    func exportSummaryCSV() -> String {
        var csv = "Date,Category,Impact,kg CO2e,Source,Notes\n"
        let formatter = ISO8601DateFormatter()
        for entry in historicalEntries {
            let row = [
                formatter.string(from: entry.date),
                entry.category.rawValue,
                entry.isSavingEntry ? "Saved" : "Emitted",
                String(format: "%.3f", entry.kgCO2),
                entry.source.rawValue,
                entry.notes ?? "",
            ].joined(separator: ",")
            csv += row + "\n"
        }
        return csv
    }

    var comparisonLabel: String {
        switch selectedPeriod {
        case .today:
            return "vs yesterday"
        case .week:
            return "vs previous 7 days"
        case .month:
            return "vs previous month"
        case .year:
            return "vs previous year"
        case .allTime:
            return "vs previous period"
        }
    }

    var drivingDistanceEquivalentText: String? {
        guard summary.totalKgSaved > 0 else { return nil }
        let distanceKm = summary.totalKgSaved / TransportMode.car.kgPerKm(in: summary.region)
        return DisplayFormatting.distance(distanceKm, region: summary.region)
    }

    var largestCategory: CategoryBreakdown? {
        summary.byCategory.max(by: { abs($0.kgCO2) < abs($1.kgCO2) })
    }

    func shareChallengeText() -> String {
        let periodLabel = selectedPeriod.rawValue.lowercased()
        let moneyText = DisplayFormatting.currency(summary.costSaved, currencyCode: summary.region.currencyCode)

        if summary.totalKgSaved > 0 {
            return "GreenCatalyst check-in: I avoided \(String(format: "%.1f", summary.totalKgSaved)) kg CO₂ and saved \(moneyText) \(periodLabel). Can you beat that?"
        }

        return "GreenCatalyst check-in: I am tracking my footprint \(periodLabel) and building lower-impact habits. Join me?"
    }

    private func previousRange(for period: SummaryPeriod) -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let now = Date.now

        switch period {
        case .today:
            let end = calendar.startOfDay(for: now)
            let start = calendar.date(byAdding: .day, value: -1, to: end)!
            return (start, end)
        case .week:
            let end = calendar.date(byAdding: .weekOfYear, value: -1, to: now)!
            let start = calendar.date(byAdding: .weekOfYear, value: -1, to: end)!
            return (start, end)
        case .month:
            let end = calendar.date(byAdding: .month, value: -1, to: now)!
            let start = calendar.date(byAdding: .month, value: -1, to: end)!
            return (start, end)
        case .year:
            let end = calendar.date(byAdding: .year, value: -1, to: now)!
            let start = calendar.date(byAdding: .year, value: -1, to: end)!
            return (start, end)
        case .allTime:
            let end = calendar.date(byAdding: .year, value: -10, to: now)!
            let start = calendar.date(byAdding: .year, value: -20, to: now)!
            return (start, end)
        }
    }
}

// MARK: - DailyTotal (Chart Model)

struct DailyTotal: Identifiable {
    let id: UUID = UUID()
    let date: Date
    let kgCO2: Double

    var dayLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
}
