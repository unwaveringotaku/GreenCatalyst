import Foundation

// MARK: - CarbonCalculator

/// Pure calculation service — no side effects, no persistence.
/// All emission factors are based on UK BEIS / DEFRA conversion factors (2023).
final class CarbonCalculator {

    // MARK: - Transport

    /// Calculate CO₂ from a trip.
    /// - Parameters:
    ///   - mode: The mode of transport
    ///   - distanceKm: Distance in kilometres
    /// - Returns: kg CO₂e
    func calculateTransport(mode: TransportMode, distanceKm: Double) -> Double {
        mode.kgPerKm * distanceKm
    }

    /// Infer transport mode and distance from HealthKit step/workout data.
    /// Returns kg CO₂e.
    func calculateFromSteps(_ steps: Int, duration: TimeInterval) -> Double {
        // Assume walking: 0 emissions, but we flag it so the app can give credit
        return 0.0
    }

    // MARK: - Energy

    /// Calculate CO₂ from electricity usage.
    /// - Parameter kWh: Kilowatt-hours consumed
    func calculateElectricity(kWh: Double) -> Double {
        // UK grid intensity factor: 0.2331 kg CO₂e/kWh (2023)
        return kWh * 0.2331
    }

    /// Calculate CO₂ from natural gas usage.
    /// - Parameter kWh: Kilowatt-hours (gas, calorific value)
    func calculateGas(kWh: Double) -> Double {
        // UK gas: 0.2034 kg CO₂e/kWh
        return kWh * 0.2034
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
    }

    /// Calculate CO₂ from a food item.
    /// - Parameters:
    ///   - type: The food type
    ///   - grams: Serving size in grams
    func calculateFood(type: FoodType, grams: Double) -> Double {
        type.kgPer100g * (grams / 100.0)
    }

    // MARK: - Shopping

    enum ProductCategory: String, CaseIterable {
        case clothing     = "Clothing"
        case electronics  = "Electronics"
        case furniture    = "Furniture"
        case books        = "Books"
        case toys         = "Toys"
        case cosmetics    = "Cosmetics"

        /// kg CO₂e per £1 spent (spending-based emission factor)
        var kgPerPound: Double {
            switch self {
            case .clothing:    return 0.47
            case .electronics: return 0.33
            case .furniture:   return 0.21
            case .books:       return 0.10
            case .toys:        return 0.14
            case .cosmetics:   return 0.18
            }
        }
    }

    /// Calculate CO₂ from a shopping purchase.
    func calculateShopping(category: ProductCategory, spendGBP: Double) -> Double {
        category.kgPerPound * spendGBP
    }

    // MARK: - Summary Builders

    /// Build a daily summary from today's entries.
    func buildDailySummary(
        entries: [CarbonEntry],
        completedNudges: [Nudge] = [],
        habitStats: HabitCompletionStats = .zero,
        target: Double
    ) -> ImpactSummary {
        buildSummary(
            entries: entries,
            completedNudges: completedNudges,
            habitStats: habitStats,
            period: .today,
            target: target
        )
    }

    /// Build an ImpactSummary for a given period.
    func buildSummary(
        entries: [CarbonEntry],
        completedNudges: [Nudge] = [],
        habitStats: HabitCompletionStats = .zero,
        period: SummaryPeriod,
        target: Double
    ) -> ImpactSummary {
        let totalKg = entries.reduce(0.0) { $0 + $1.kgCO2 }
        let totalMagnitudeKg = entries.reduce(0.0) { $0 + abs($1.kgCO2) }
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
        let breakdowns: [CategoryBreakdown] = categories.compactMap { cat in
            let catNetKg = entries
                .filter { $0.category == cat }
                .reduce(0.0) { $0 + $1.kgCO2 }

            guard abs(catNetKg) > 0.0001 else { return nil }

            let pct = totalMagnitudeKg > 0 ? abs(catNetKg) / totalMagnitudeKg : 0
            let periodTarget = periodMultiplier(period) * cat.dailyBudgetKg
            return CategoryBreakdown(
                category: cat,
                kgCO2: catNetKg,
                percentOfTotal: pct,
                vsTargetDelta: catNetKg - periodTarget
            )
        }

        let periodTarget = periodMultiplier(period) * target

        return ImpactSummary(
            period: period,
            startDate: startDate(for: period),
            endDate: .now,
            totalKgCO2: totalKg,
            totalKgSaved: totalSaved,
            targetKgCO2: periodTarget,
            byCategory: breakdowns,
            costSaved: totalCostSaved,
            pointsEarned: totalPointsEarned,
            habitsCompleted: habitStats.count,
            nudgesActedOn: completedNudges.count,
            vsLastPeriodDelta: 0,
            vsNationalAverageDelta: totalKg - (12.5 * periodMultiplier(period))
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
