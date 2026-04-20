import AppIntents
import Foundation

// MARK: - GetCarbonScoreIntent

struct GetCarbonScoreIntent: AppIntent {

    static var title: LocalizedStringResource { "Get Carbon Score" }
    static var description: IntentDescription {
        IntentDescription(
            "Returns today's total CO₂ footprint and tells you if you're on track.",
            categoryName: "Carbon Tracking"
        )
    }

    static var openAppWhenRun: Bool { false }

    // MARK: - Perform

    func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<Double> {
        let (totalKg, target) = try await MainActor.run {
            let store = DataStore.shared
            let entries = try store.fetchTodaysEntriesSync()
            let totalKg = entries.reduce(0.0) { $0 + $1.kgCO2 }
            let profile = try store.fetchUserProfileSync()
            return (totalKg, profile.targetKgPerDay)
        }

        let dialog = buildDialog(totalKg: totalKg, target: target)
        return .result(value: totalKg, dialog: dialog)
    }

    // MARK: - Dialog Builder

    private func buildDialog(totalKg: Double, target: Double) -> IntentDialog {
        let formattedKg = String(format: "%.1f", totalKg)
        let formattedTarget = String(format: "%.0f", target)
        let remaining = target - totalKg

        if totalKg == 0 {
            return IntentDialog(
                full: "You have not logged any activity yet today. Your net footprint target is \(formattedTarget) kg CO₂.",
                supporting: "No entries today."
            )
        }

        if totalKg < 0 {
            let avoided = String(format: "%.1f", abs(totalKg))
            return IntentDialog(
                full: "Your logged savings currently outweigh your emissions. You are \(avoided) kg CO₂ below zero and well under your \(formattedTarget) kg target.",
                supporting: "\(avoided) kg CO₂ net avoided so far."
            )
        }

        if remaining > 0 {
            let remainingFormatted = String(format: "%.1f", remaining)
            return IntentDialog(
                full: "Your net footprint is \(formattedKg) kg CO₂ today. You are under your \(formattedTarget) kg target with \(remainingFormatted) kg remaining.",
                supporting: "\(formattedKg) kg used, \(remainingFormatted) kg remaining."
            )
        } else {
            let over = String(format: "%.1f", abs(remaining))
            return IntentDialog(
                full: "Your net footprint is \(formattedKg) kg CO₂ today, which is \(over) kg over your \(formattedTarget) kg target.",
                supporting: "\(formattedKg) kg used, \(over) kg over target."
            )
        }
    }
}

// MARK: - CarbonScoreEntity (for Widget & Spotlight)

struct CarbonScoreEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Carbon Score" }
    static var defaultQuery: CarbonScoreQuery { CarbonScoreQuery() }

    var id: String
    var kgCO2Today: Double
    var targetKg: Double
    var isUnderTarget: Bool
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(String(format: "%.1f", kgCO2Today)) kg CO₂ today",
            subtitle: isUnderTarget ? "Under target 🌿" : "Over target ⚠️"
        )
    }

    static var sample: CarbonScoreEntity {
        CarbonScoreEntity(
            id: "today",
            kgCO2Today: 4.6,
            targetKg: 8.0,
            isUnderTarget: true
        )
    }
}

struct CarbonScoreQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [CarbonScoreEntity] {
        let entity = try await MainActor.run {
            let store = DataStore.shared
            let entries = try store.fetchTodaysEntriesSync()
            let profile = try store.fetchUserProfileSync()
            let total = entries.reduce(0.0) { $0 + $1.kgCO2 }
            return CarbonScoreEntity(
                id: "today",
                kgCO2Today: total,
                targetKg: profile.targetKgPerDay,
                isUnderTarget: total <= profile.targetKgPerDay
            )
        }
        return [entity]
    }

    func suggestedEntities() async throws -> [CarbonScoreEntity] {
        return try await entities(for: ["today"])
    }

    func defaultResult() async -> CarbonScoreEntity? {
        return try? await suggestedEntities().first
    }
}
