import Foundation
import SwiftData

// MARK: - Category

/// Top-level emission category for a carbon entry
enum CarbonCategory: String, Codable, CaseIterable, Identifiable {
    case energy     = "Energy"
    case transport  = "Transport"
    case food       = "Food"
    case shopping   = "Shopping"
    case other      = "Other"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .energy:    return "bolt.fill"
        case .transport: return "car.fill"
        case .food:      return "fork.knife"
        case .shopping:  return "bag.fill"
        case .other:     return "ellipsis.circle.fill"
        }
    }

    var color: String {
        switch self {
        case .energy:    return "#FFB300"
        case .transport: return "#E53935"
        case .food:      return "#43A047"
        case .shopping:  return "#8E24AA"
        case .other:     return "#546E7A"
        }
    }

    /// Average UK per-category daily budget in kg CO₂e
    var dailyBudgetKg: Double {
        switch self {
        case .energy:    return 2.5
        case .transport: return 4.0
        case .food:      return 2.8
        case .shopping:  return 1.8
        case .other:     return 0.9
        }
    }
}

// MARK: - Source

/// How the carbon entry was recorded
enum CarbonSource: String, Codable, CaseIterable {
    case manual      = "Manual"
    case healthKit   = "HealthKit"
    case location    = "Location"
    case ai          = "AI Scan"

    var icon: String {
        switch self {
        case .manual:    return "pencil"
        case .healthKit: return "heart.fill"
        case .location:  return "location.fill"
        case .ai:        return "sparkles"
        }
    }
}

// MARK: - TransportMode

enum TransportMode: String, Codable, CaseIterable {
    case walking   = "Walking"
    case cycling   = "Cycling"
    case running   = "Running"
    case car       = "Car"
    case publicTransport = "Public Transport"
    case flight    = "Flight"
    case ferry     = "Ferry"

    /// Emission factor in kg CO₂e per km
    var kgPerKm: Double {
        switch self {
        case .walking:          return 0.0
        case .cycling:          return 0.0
        case .running:          return 0.0
        case .car:              return 0.171   // average UK petrol car
        case .publicTransport:  return 0.089   // average UK bus
        case .flight:           return 0.255   // short-haul per km
        case .ferry:            return 0.113
        }
    }

    var icon: String {
        switch self {
        case .walking:          return "figure.walk"
        case .cycling:          return "bicycle"
        case .running:          return "figure.run"
        case .car:              return "car.fill"
        case .publicTransport:  return "bus.fill"
        case .flight:           return "airplane"
        case .ferry:            return "ferry.fill"
        }
    }
}

// MARK: - CarbonEntry

/// A single recorded carbon event. Stored via SwiftData.
@Model
final class CarbonEntry: Identifiable {
    var id: UUID
    var date: Date
    var category: CarbonCategory
    var kgCO2: Double
    var source: CarbonSource
    var notes: String?
    var transportMode: TransportMode?
    var distanceKm: Double?
    var isVerified: Bool

    // Derived metadata
    var createdAt: Date

    init(
        id: UUID = UUID(),
        date: Date = .now,
        category: CarbonCategory,
        kgCO2: Double,
        source: CarbonSource = .manual,
        notes: String? = nil,
        transportMode: TransportMode? = nil,
        distanceKm: Double? = nil,
        isVerified: Bool = false
    ) {
        self.id = id
        self.date = date
        self.category = category
        self.kgCO2 = kgCO2
        self.source = source
        self.notes = notes
        self.transportMode = transportMode
        self.distanceKm = distanceKm
        self.isVerified = isVerified
        self.createdAt = .now
    }
}

// MARK: - Equatable

extension CarbonEntry: Equatable {
    static func == (lhs: CarbonEntry, rhs: CarbonEntry) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Sample Data

extension CarbonEntry {
    static var sampleEntries: [CarbonEntry] {
        [
            CarbonEntry(
                date: .now,
                category: .transport,
                kgCO2: 2.4,
                source: .location,
                notes: "Morning commute by car",
                transportMode: .car,
                distanceKm: 14.0
            ),
            CarbonEntry(
                date: .now,
                category: .food,
                kgCO2: 0.9,
                source: .manual,
                notes: "Chicken salad lunch"
            ),
            CarbonEntry(
                date: Calendar.current.date(byAdding: .hour, value: -3, to: .now)!,
                category: .energy,
                kgCO2: 1.2,
                source: .manual,
                notes: "Home heating"
            ),
        ]
    }
}
