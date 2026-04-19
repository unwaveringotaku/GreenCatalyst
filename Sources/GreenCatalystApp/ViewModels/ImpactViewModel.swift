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
            historicalEntries = entries
            summary = carbonCalculator.buildSummary(
                entries: entries,
                completedNudges: completedNudges,
                period: selectedPeriod,
                target: profile.targetKgPerDay
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
        var csv = "Date,Category,kg CO2,Source,Notes\n"
        let formatter = ISO8601DateFormatter()
        for entry in historicalEntries {
            let row = [
                formatter.string(from: entry.date),
                entry.category.rawValue,
                String(format: "%.3f", entry.kgCO2),
                entry.source.rawValue,
                entry.notes ?? "",
            ].joined(separator: ",")
            csv += row + "\n"
        }
        return csv
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
