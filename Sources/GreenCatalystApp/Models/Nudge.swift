import Foundation
import SwiftData

// MARK: - NudgePriority

enum NudgePriority: Int, Codable, Comparable {
    case low    = 0
    case medium = 1
    case high   = 2

    static func < (lhs: NudgePriority, rhs: NudgePriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Nudge

/// A time-sensitive action card the app surfaces to help reduce CO₂.
@Model
final class Nudge: Identifiable {
    var id: UUID
    var title: String
    var nudgeDescription: String
    var co2Saving: Double           // kg CO₂ saved if action is taken
    var costSaving: Double          // £ saved
    var category: CarbonCategory
    var priority: NudgePriority
    var icon: String                // SF Symbol
    var isCompleted: Bool
    var isDismissed: Bool
    var expiresAt: Date?
    var deepLinkAction: String?     // e.g. "log-transport", "open-map"
    var createdAt: Date
    var completedAt: Date?

    init(
        id: UUID = UUID(),
        title: String,
        description: String,
        co2Saving: Double,
        costSaving: Double = 0,
        category: CarbonCategory,
        priority: NudgePriority = .medium,
        icon: String,
        expiresAt: Date? = nil,
        deepLinkAction: String? = nil
    ) {
        self.id = id
        self.title = title
        self.nudgeDescription = description
        self.co2Saving = co2Saving
        self.costSaving = costSaving
        self.category = category
        self.priority = priority
        self.icon = icon
        self.isCompleted = false
        self.isDismissed = false
        self.expiresAt = expiresAt
        self.deepLinkAction = deepLinkAction
        self.createdAt = .now
        self.completedAt = nil
    }

    // MARK: - Computed

    var isExpired: Bool {
        guard let expiry = expiresAt else { return false }
        return Date.now > expiry
    }

    var isActive: Bool {
        !isCompleted && !isDismissed && !isExpired
    }

    var timeRemainingText: String? {
        guard let expiry = expiresAt, !isExpired else { return nil }
        let remaining = expiry.timeIntervalSince(.now)
        let hours = Int(remaining / 3600)
        let minutes = Int((remaining.truncatingRemainder(dividingBy: 3600)) / 60)
        if hours > 0 { return "Expires in \(hours)h \(minutes)m" }
        return "Expires in \(minutes)m"
    }

    // MARK: - Methods

    func markCompleted() {
        isCompleted = true
        completedAt = .now
    }

    func dismiss() {
        isDismissed = true
    }

    @discardableResult
    func refreshForVersion102IfNeeded() -> Bool {
        let normalizedTitle = title.lowercased()

        switch normalizedTitle {
        case "choose cycling for a short trip", "try biking or transit for your work trip":
            return applyVersion102Values(
                title: "Try biking or transit for your work trip",
                description: "For a 14 mi round trip, swapping the car for biking or public transport can avoid about 2.4 kg CO₂ and save around $3.50. Best before you leave.",
                co2Saving: 2.4,
                costSaving: 3.50,
                category: .transport,
                priority: .high,
                icon: "bicycle",
                expiresAt: Calendar.current.date(byAdding: .hour, value: 8, to: createdAt),
                deepLinkAction: "log-transport"
            )
        case "switch to a plant-based lunch", "pick the lighter lunch today":
            return applyVersion102Values(
                title: "Pick the lighter lunch today",
                description: "Switching one higher-impact lunch to a plant-based option can avoid about 1.8 kg CO₂ and save around $2.00. Helpful before you order.",
                co2Saving: 1.8,
                costSaving: 2.00,
                category: .food,
                priority: .medium,
                icon: "leaf.fill",
                expiresAt: Calendar.current.date(byAdding: .hour, value: 4, to: createdAt),
                deepLinkAction: nil
            )
        case "switch off unused electronics", "shut down your desk setup when you pause":
            return applyVersion102Values(
                title: "Shut down your desk setup when you pause",
                description: "Turning off screens and chargers during breaks trims wasted energy while the task is still in progress, avoiding roughly 0.6 kg CO₂.",
                co2Saving: 0.6,
                costSaving: 0.45,
                category: .energy,
                priority: .low,
                icon: "bolt.slash.fill",
                expiresAt: nil,
                deepLinkAction: nil
            )
        case "shop second-hand this weekend", "check resale before buying new":
            return applyVersion102Values(
                title: "Check resale before buying new",
                description: "If this weekend errand turns into a purchase, checking second-hand first can avoid several kilograms of CO₂ and save around $25.",
                co2Saving: 3.0,
                costSaving: 25.00,
                category: .shopping,
                priority: .low,
                icon: "arrow.2.circlepath",
                expiresAt: Calendar.current.date(byAdding: .day, value: 2, to: createdAt),
                deepLinkAction: nil
            )
        default:
            return false
        }
    }

    private func applyVersion102Values(
        title: String,
        description: String,
        co2Saving: Double,
        costSaving: Double,
        category: CarbonCategory,
        priority: NudgePriority,
        icon: String,
        expiresAt: Date?,
        deepLinkAction: String?
    ) -> Bool {
        let didChange =
            self.title != title ||
            self.nudgeDescription != description ||
            self.co2Saving != co2Saving ||
            self.costSaving != costSaving ||
            self.category != category ||
            self.priority != priority ||
            self.icon != icon ||
            self.expiresAt != expiresAt ||
            self.deepLinkAction != deepLinkAction

        guard didChange else { return false }

        self.title = title
        self.nudgeDescription = description
        self.co2Saving = co2Saving
        self.costSaving = costSaving
        self.category = category
        self.priority = priority
        self.icon = icon
        self.expiresAt = expiresAt
        self.deepLinkAction = deepLinkAction
        return true
    }
}

// MARK: - Equatable

extension Nudge: Equatable {
    static func == (lhs: Nudge, rhs: Nudge) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Sample Data

extension Nudge {
    static var sampleNudges: [Nudge] {
        let now = Date.now
        return [
            Nudge(
                title: "Try biking or transit for your work trip",
                description: "For a 14 mi round trip, swapping the car for biking or public transport can avoid about 2.4 kg CO₂ and save around $3.50. Best before you leave.",
                co2Saving: 2.4,
                costSaving: 3.50,
                category: .transport,
                priority: .high,
                icon: "bicycle",
                expiresAt: Calendar.current.date(byAdding: .hour, value: 8, to: now),
                deepLinkAction: "log-transport"
            ),
            Nudge(
                title: "Pick the lighter lunch today",
                description: "Switching one higher-impact lunch to a plant-based option can avoid about 1.8 kg CO₂ and save around $2.00. Helpful before you order.",
                co2Saving: 1.8,
                costSaving: 2.00,
                category: .food,
                priority: .medium,
                icon: "leaf.fill",
                expiresAt: Calendar.current.date(byAdding: .hour, value: 4, to: now)
            ),
            Nudge(
                title: "Shut down your desk setup when you pause",
                description: "Turning off screens and chargers during breaks trims wasted energy while the task is still in progress, avoiding roughly 0.6 kg CO₂.",
                co2Saving: 0.6,
                costSaving: 0.45,
                category: .energy,
                priority: .low,
                icon: "bolt.slash.fill"
            ),
            Nudge(
                title: "Check resale before buying new",
                description: "If this weekend errand turns into a purchase, checking second-hand first can avoid several kilograms of CO₂ and save around $25.",
                co2Saving: 3.0,
                costSaving: 25.00,
                category: .shopping,
                priority: .low,
                icon: "arrow.2.circlepath",
                expiresAt: Calendar.current.date(byAdding: .day, value: 2, to: now)
            ),
        ]
    }
}
