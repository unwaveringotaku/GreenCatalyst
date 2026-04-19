import Foundation
import SwiftData

// MARK: - HabitFrequency

enum HabitFrequency: String, Codable, CaseIterable {
    case daily   = "Daily"
    case weekly  = "Weekly"
    case monthly = "Monthly"
}

// MARK: - Habit

/// A sustainable behaviour the user is trying to build.
@Model
final class Habit: Identifiable {
    var id: UUID
    var name: String
    var habitDescription: String
    var category: CarbonCategory
    var frequency: HabitFrequency
    var streakCount: Int
    var longestStreak: Int
    var lastCompleted: Date?
    var co2PerAction: Double        // kg CO₂ saved each time completed
    var costPerAction: Double       // £ saved each time completed
    var icon: String                // SF Symbol name
    var colorHex: String            // hex string for accent
    var isActive: Bool
    var reminderTime: Date?         // nil = no reminder
    var completionDates: [Date]
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        habitDescription: String = "",
        category: CarbonCategory,
        frequency: HabitFrequency = .daily,
        co2PerAction: Double,
        costPerAction: Double = 0,
        icon: String,
        colorHex: String = "#43A047",
        isActive: Bool = true,
        reminderTime: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.habitDescription = habitDescription
        self.category = category
        self.frequency = frequency
        self.streakCount = 0
        self.longestStreak = 0
        self.lastCompleted = nil
        self.co2PerAction = co2PerAction
        self.costPerAction = costPerAction
        self.icon = icon
        self.colorHex = colorHex
        self.isActive = isActive
        self.reminderTime = reminderTime
        self.completionDates = []
        self.createdAt = .now
    }

    // MARK: - Computed

    /// Whether the habit was completed today
    var isCompletedToday: Bool {
        guard let last = lastCompleted else { return false }
        return Calendar.current.isDateInToday(last)
    }

    /// Whether the streak is at risk (not completed today and frequency is daily)
    var isStreakAtRisk: Bool {
        guard frequency == .daily, streakCount > 0 else { return false }
        return !isCompletedToday
    }

    /// Total CO₂ saved across all completions
    var totalCO2Saved: Double {
        Double(completionDates.count) * co2PerAction
    }

    /// Total cost saved
    var totalCostSaved: Double {
        Double(completionDates.count) * costPerAction
    }

    // MARK: - Methods

    /// Mark the habit as completed now, updating streak logic.
    func markCompleted(at date: Date = .now) {
        completionDates.append(date)
        let calendar = Calendar.current

        if let last = lastCompleted {
            let daysBetween = calendar.dateComponents([.day], from: last, to: date).day ?? 0
            switch frequency {
            case .daily:
                streakCount = (daysBetween == 1) ? streakCount + 1 : 1
            case .weekly:
                streakCount = (daysBetween <= 7) ? streakCount + 1 : 1
            case .monthly:
                let months = calendar.dateComponents([.month], from: last, to: date).month ?? 0
                streakCount = (months == 1) ? streakCount + 1 : 1
            }
        } else {
            streakCount = 1
        }

        longestStreak = max(longestStreak, streakCount)
        lastCompleted = date
    }
}

// MARK: - Equatable

extension Habit: Equatable {
    static func == (lhs: Habit, rhs: Habit) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Sample Data

extension Habit {
    static var defaults: [Habit] {
        [
            Habit(
                name: "Bike to Work",
                habitDescription: "Cycle instead of driving for your commute",
                category: .transport,
                co2PerAction: 2.4,
                costPerAction: 3.50,
                icon: "bicycle",
                colorHex: "#43A047"
            ),
            Habit(
                name: "Meat-Free Monday",
                habitDescription: "Skip meat once a week",
                category: .food,
                frequency: .weekly,
                co2PerAction: 1.8,
                costPerAction: 2.00,
                icon: "leaf.fill",
                colorHex: "#66BB6A"
            ),
            Habit(
                name: "Short Shower",
                habitDescription: "Keep showers under 4 minutes",
                category: .energy,
                co2PerAction: 0.4,
                costPerAction: 0.30,
                icon: "drop.fill",
                colorHex: "#29B6F6"
            ),
            Habit(
                name: "Reusable Bag",
                habitDescription: "Bring your own bag when shopping",
                category: .shopping,
                co2PerAction: 0.05,
                costPerAction: 0.10,
                icon: "bag.fill",
                colorHex: "#AB47BC"
            ),
        ]
    }
}
