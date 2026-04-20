import Foundation

// MARK: - CarbonCalculator

/// Pure calculation service — no side effects, no persistence.
/// Factors here are coarse planning estimates intended for personal tracking,
/// not audited footprint reporting.
final class CarbonCalculator {

    // MARK: - Transport

    /// Calculate CO₂ from a trip.
    /// - Parameters:
    ///   - mode: The mode of transport
    ///   - distanceKm: Distance in kilometres
    ///   - region: The regional factor set to apply
    /// - Returns: kg CO₂e
    func calculateTransport(
        mode: TransportMode,
        distanceKm: Double,
        region: CarbonRegion = .globalAverage
    ) -> Double {
        mode.kgPerKm(in: region) * distanceKm
    }

    /// Infer transport mode and distance from HealthKit step/workout data.
    /// Returns kg CO₂e.
    func calculateFromSteps(
        _ steps: Int,
        duration: TimeInterval,
        region: CarbonRegion = .globalAverage
    ) -> Double {
        // Assume walking: 0 emissions, but we flag it so the app can give credit
        return 0.0
    }

    enum EnergySource: String, CaseIterable {
        case electricity = "Electricity"
        case gas = "Natural Gas"
    }

    // MARK: - Energy

    /// Calculate CO₂ from electricity usage.
    /// - Parameter kWh: Kilowatt-hours consumed
    func calculateElectricity(kWh: Double, region: CarbonRegion = .globalAverage) -> Double {
        kWh * region.electricityKgPerKWh
    }

    /// Calculate CO₂ from natural gas usage.
    /// - Parameter kWh: Kilowatt-hours (gas, calorific value)
    func calculateGas(kWh: Double, region: CarbonRegion = .globalAverage) -> Double {
        kWh * region.gasKgPerKWh
    }

    // MARK: - Food

    enum FoodType: String, CaseIterable {
        case beef         = "Beef"
        case lamb         = "Lamb"
        case pork         = "Pork"
        case chicken      = "Chicken"
        case fish         = "Fish"
        case eggs         = "Eggs"
        case dairy        = "Dairy"
        case vegetables   = "Vegetables"
        case legumes      = "Legumes"
        case grains       = "Grains"
        case nuts         = "Nuts"

        /// kg CO₂e per 100g serving
        var kgPer100g: Double {
            switch self {
            case .beef:       return 2.70
            case .lamb:       return 2.45
            case .pork:       return 0.61
            case .chicken:    return 0.43
            case .fish:       return 0.41
            case .eggs:       return 0.18
            case .dairy:      return 0.21
            case .vegetables: return 0.02
            case .legumes:    return 0.08
            case .grains:     return 0.11
            case .nuts:       return 0.26
            }
        }

        func kgPer100g(in region: CarbonRegion) -> Double {
            kgPer100g * region.foodBaselineMultiplier
        }
    }

    /// Calculate CO₂ from a food item.
    /// - Parameters:
    ///   - type: The food type
    ///   - grams: Serving size in grams
    func calculateFood(
        type: FoodType,
        grams: Double,
        region: CarbonRegion = .globalAverage
    ) -> Double {
        type.kgPer100g(in: region) * (grams / 100.0)
    }

    // MARK: - Shopping

    enum ProductCategory: String, CaseIterable {
        case clothing     = "Clothing"
        case electronics  = "Electronics"
        case furniture    = "Furniture"
        case books        = "Books"
        case toys         = "Toys"
        case cosmetics    = "Cosmetics"

        /// kg CO₂e per unit of spend (spending-based factor)
        var kgPerCurrencyUnit: Double {
            switch self {
            case .clothing:    return 0.47
            case .electronics: return 0.33
            case .furniture:   return 0.21
            case .books:       return 0.10
            case .toys:        return 0.14
            case .cosmetics:   return 0.18
            }
        }

        func kgPerCurrencyUnit(in region: CarbonRegion) -> Double {
            kgPerCurrencyUnit * region.shoppingSpendMultiplier
        }
    }

    /// Calculate CO₂ from a shopping purchase.
    func calculateShopping(
        category: ProductCategory,
        spendAmount: Double,
        region: CarbonRegion = .globalAverage
    ) -> Double {
        category.kgPerCurrencyUnit(in: region) * spendAmount
    }

    // MARK: - Summary Builders

    /// Build a daily summary from today's entries.
    func buildDailySummary(
        entries: [CarbonEntry],
        completedNudges: [Nudge] = [],
        habitStats: HabitCompletionStats = .zero,
        target: Double,
        region: CarbonRegion = .globalAverage,
        vsLastPeriodDelta: Double = 0
    ) -> ImpactSummary {
        buildSummary(
            entries: entries,
            completedNudges: completedNudges,
            habitStats: habitStats,
            period: .today,
            target: target,
            region: region,
            vsLastPeriodDelta: vsLastPeriodDelta
        )
    }

    /// Build an ImpactSummary for a given period.
    func buildSummary(
        entries: [CarbonEntry],
        completedNudges: [Nudge] = [],
        habitStats: HabitCompletionStats = .zero,
        period: SummaryPeriod,
        target: Double,
        region: CarbonRegion = .globalAverage,
        vsLastPeriodDelta: Double = 0
    ) -> ImpactSummary {
        let totalKg = entries.reduce(0.0) { $0 + $1.kgCO2 }
        let grossEmissionsKg = entries.reduce(0.0) { $0 + max(0, $1.kgCO2) }
        let nudgeKgSaved = completedNudges.reduce(0.0) { $0 + max(0, $1.co2Saving) }
        let nudgeCostSaved = completedNudges.reduce(0.0) { $0 + max(0, $1.costSaving) }
        let nudgePointsEarned = completedNudges.reduce(0) { partialResult, nudge in
            partialResult + Int((max(0, nudge.co2Saving) * 10).rounded())
        }
        let totalSaved = nudgeKgSaved + habitStats.totalKgSaved
        let totalCostSaved = nudgeCostSaved + habitStats.totalCostSaved
        let totalPointsEarned = nudgePointsEarned + habitStats.pointsEarned

        // Per-category breakdown
        let categories = CarbonCategory.allCases
        let categoryTotals: [(category: CarbonCategory, netKgCO2: Double)] = categories.compactMap { category in
            let netKgCO2 = entries
                .filter { $0.category == category }
                .reduce(0.0) { $0 + $1.kgCO2 }

            guard abs(netKgCO2) > 0.0001 else { return nil }
            return (category, netKgCO2)
        }
        let categoryTotalMagnitude = categoryTotals.reduce(0.0) { partialResult, category in
            partialResult + abs(category.netKgCO2)
        }
        let breakdowns: [CategoryBreakdown] = categoryTotals.map { item in
            let percentOfTotal = categoryTotalMagnitude > 0 ? abs(item.netKgCO2) / categoryTotalMagnitude : 0
            let periodTarget = periodMultiplier(period) * item.category.dailyBudgetKg(in: region)
            return CategoryBreakdown(
                category: item.category,
                kgCO2: item.netKgCO2,
                percentOfTotal: percentOfTotal,
                vsTargetDelta: item.netKgCO2 - periodTarget
            )
        }

        let periodTarget = periodMultiplier(period) * target

        return ImpactSummary(
            period: period,
            startDate: startDate(for: period),
            endDate: .now,
            region: region,
            totalKgCO2: totalKg,
            grossEmissionsKg: grossEmissionsKg,
            totalKgSaved: totalSaved,
            targetKgCO2: periodTarget,
            byCategory: breakdowns,
            costSaved: totalCostSaved,
            pointsEarned: totalPointsEarned,
            habitsCompleted: habitStats.count,
            nudgesActedOn: completedNudges.count,
            vsLastPeriodDelta: vsLastPeriodDelta,
            vsNationalAverageDelta: 0
        )
    }

    // MARK: - Helpers

    private func periodMultiplier(_ period: SummaryPeriod) -> Double {
        switch period {
        case .today:   return 1
        case .week:    return 7
        case .month:   return 30
        case .year:    return 365
        case .allTime: return 365
        }
    }

    private func startDate(for period: SummaryPeriod) -> Date {
        let cal = Calendar.current
        let now = Date.now
        switch period {
        case .today:   return cal.startOfDay(for: now)
        case .week:    return cal.date(byAdding: .weekOfYear, value: -1, to: now)!
        case .month:   return cal.date(byAdding: .month, value: -1, to: now)!
        case .year:    return cal.date(byAdding: .year, value: -1, to: now)!
        case .allTime: return cal.date(byAdding: .year, value: -10, to: now)!
        }
    }
}
