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
                title: "Cycle to work today",
                description: "It's sunny and 18°C — perfect cycling weather. Save 2.4 kg CO₂ vs driving.",
                co2Saving: 2.4,
                costSaving: 3.50,
                category: .transport,
                priority: .high,
                icon: "bicycle",
                expiresAt: Calendar.current.date(byAdding: .hour, value: 8, to: now),
                deepLinkAction: "log-transport"
            ),
            Nudge(
                title: "Switch to a plant-based lunch",
                description: "Swapping today's meal saves 1.8 kg CO₂ — that's equivalent to driving 10 km.",
                co2Saving: 1.8,
                costSaving: 2.00,
                category: .food,
                priority: .medium,
                icon: "leaf.fill",
                expiresAt: Calendar.current.date(byAdding: .hour, value: 4, to: now)
            ),
            Nudge(
                title: "Turn off standby appliances",
                description: "Your home used 15% more energy than average last night. Unplugging saves 0.6 kg CO₂.",
                co2Saving: 0.6,
                costSaving: 0.45,
                category: .energy,
                priority: .low,
                icon: "bolt.slash.fill"
            ),
            Nudge(
                title: "Shop second-hand this weekend",
                description: "Buying pre-loved items instead of new saves up to 3 kg CO₂ per purchase.",
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
