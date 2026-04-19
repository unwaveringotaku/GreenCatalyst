import Foundation

// MARK: - Period

enum SummaryPeriod: String, Codable, CaseIterable, Identifiable {
    case today  = "Today"
    case week   = "This Week"
    case month  = "This Month"
    case year   = "This Year"
    case allTime = "All Time"

    var id: String { rawValue }

    var calendarComponent: Calendar.Component {
        switch self {
        case .today:   return .day
        case .week:    return .weekOfYear
        case .month:   return .month
        case .year:    return .year
        case .allTime: return .era
        }
    }
}

// MARK: - Equivalency

/// A human-readable CO₂ equivalency to make the number tangible
struct Equivalency: Identifiable {
    let id: UUID
    let icon: String
    let label: String

    init(icon: String, label: String) {
        self.id = UUID()
        self.icon = icon
        self.label = label
    }
}

// MARK: - CategoryBreakdown

struct CategoryBreakdown: Identifiable {
    let id: UUID
    let category: CarbonCategory
    let kgCO2: Double
    let percentOfTotal: Double
    let vsTargetDelta: Double          // positive = over target, negative = under

    init(category: CarbonCategory, kgCO2: Double, percentOfTotal: Double, vsTargetDelta: Double) {
        self.id = UUID()
        self.category = category
        self.kgCO2 = kgCO2
        self.percentOfTotal = percentOfTotal
        self.vsTargetDelta = vsTargetDelta
    }
}

// MARK: - ImpactSummary

/// Aggregated carbon impact report for a given time period.
struct ImpactSummary: Identifiable {
    let id: UUID
    let period: SummaryPeriod
    let startDate: Date
    let endDate: Date

    // Core metrics
    let totalKgCO2: Double
    let totalKgSaved: Double          // vs baseline / target
    let targetKgCO2: Double

    // Breakdown
    let byCategory: [CategoryBreakdown]
    let equivalencies: [Equivalency]

    // Financial
    let costSaved: Double             // £ saved vs baseline

    // Gamification
    let pointsEarned: Int
    let habitsCompleted: Int
    let nudgesActedOn: Int

    // Comparison
    let vsLastPeriodDelta: Double     // kg CO₂, negative = improvement
    let vsNationalAverageDelta: Double

    init(
        id: UUID = UUID(),
        period: SummaryPeriod,
        startDate: Date,
        endDate: Date,
        totalKgCO2: Double,
        totalKgSaved: Double,
        targetKgCO2: Double,
        byCategory: [CategoryBreakdown],
        costSaved: Double,
        pointsEarned: Int,
        habitsCompleted: Int,
        nudgesActedOn: Int,
        vsLastPeriodDelta: Double,
        vsNationalAverageDelta: Double
    ) {
        self.id = id
        self.period = period
        self.startDate = startDate
        self.endDate = endDate
        self.totalKgCO2 = totalKgCO2
        self.totalKgSaved = totalKgSaved
        self.targetKgCO2 = targetKgCO2
        self.byCategory = byCategory
        self.costSaved = costSaved
        self.pointsEarned = pointsEarned
        self.habitsCompleted = habitsCompleted
        self.nudgesActedOn = nudgesActedOn
        self.vsLastPeriodDelta = vsLastPeriodDelta
        self.vsNationalAverageDelta = vsNationalAverageDelta
        self.equivalencies = ImpactSummary.equivalencies(for: totalKgSaved)
    }

    // MARK: - Computed

    var score: Int {
        // 0-100 score: ratio of target met
        guard targetKgCO2 > 0 else { return 0 }
        let ratio = totalKgCO2 / targetKgCO2
        return max(0, min(100, Int((1 - ratio) * 100) + 50))
    }

    var isUnderTarget: Bool { totalKgCO2 <= targetKgCO2 }

    var progressPercent: Double {
        guard targetKgCO2 > 0 else { return 0 }
        return min(1.0, abs(totalKgCO2) / targetKgCO2)
    }

    // MARK: - Equivalency factory

    static func equivalencies(for kgSaved: Double) -> [Equivalency] {
        var result: [Equivalency] = []
        if kgSaved >= 0.1 {
            let km = kgSaved / 0.171
            result.append(Equivalency(icon: "car.fill", label: String(format: "%.0f km not driven", km)))
        }
        if kgSaved >= 0.5 {
            let trees = kgSaved / 21.0      // 1 tree absorbs ~21 kg CO₂/year
            result.append(Equivalency(icon: "tree.fill", label: String(format: "%.2f trees planted (annual)", trees)))
        }
        if kgSaved >= 1.0 {
            let phones = kgSaved / 0.00885   // 1 smartphone charge = 8.85 g CO₂
            result.append(Equivalency(icon: "iphone", label: String(format: "%.0f phone charges avoided", phones)))
        }
        if kgSaved >= 2.0 {
            let meals = kgSaved / 1.8
            result.append(Equivalency(icon: "fork.knife", label: String(format: "%.0f plant-based meals", meals)))
        }
        return result
    }
}

// MARK: - Sample Data

extension ImpactSummary {
    static func empty(
        period: SummaryPeriod = .today,
        targetKgCO2: Double = 8.0
    ) -> ImpactSummary {
        ImpactSummary(
            period: period,
            startDate: Calendar.current.startOfDay(for: .now),
            endDate: .now,
            totalKgCO2: 0,
            totalKgSaved: 0,
            targetKgCO2: targetKgCO2,
            byCategory: [],
            costSaved: 0,
            pointsEarned: 0,
            habitsCompleted: 0,
            nudgesActedOn: 0,
            vsLastPeriodDelta: 0,
            vsNationalAverageDelta: period == .today ? -12.5 : 0
        )
    }

    static var todaySample: ImpactSummary {
        let breakdowns: [CategoryBreakdown] = [
            CategoryBreakdown(category: .transport, kgCO2: 2.4, percentOfTotal: 0.52, vsTargetDelta: -1.6),
            CategoryBreakdown(category: .food,      kgCO2: 1.2, percentOfTotal: 0.26, vsTargetDelta: -1.6),
            CategoryBreakdown(category: .energy,    kgCO2: 0.8, percentOfTotal: 0.17, vsTargetDelta: -1.7),
            CategoryBreakdown(category: .shopping,  kgCO2: 0.2, percentOfTotal: 0.04, vsTargetDelta: -1.6),
        ]
        return ImpactSummary(
            period: .today,
            startDate: Calendar.current.startOfDay(for: .now),
            endDate: .now,
            totalKgCO2: 4.6,
            totalKgSaved: 3.4,
            targetKgCO2: 8.0,
            byCategory: breakdowns,
            costSaved: 5.20,
            pointsEarned: 46,
            habitsCompleted: 2,
            nudgesActedOn: 1,
            vsLastPeriodDelta: -0.8,
            vsNationalAverageDelta: -7.9
        )
    }
}
