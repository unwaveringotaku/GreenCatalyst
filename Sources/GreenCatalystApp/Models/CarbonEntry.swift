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

    /// Default per-category daily budget in kg CO₂e for the global average.
    var dailyBudgetKg: Double {
        dailyBudgetKg(in: .globalAverage)
    }

    func dailyBudgetKg(in region: CarbonRegion) -> Double {
        switch self {
        case .energy:
            switch region {
            case .northAmerica:     return 3.6
            case .unitedKingdom:    return 2.5
            case .continentalEurope:return 2.2
            case .oceania:          return 3.8
            case .globalAverage:    return 2.8
            }
        case .transport:
            switch region {
            case .northAmerica:     return 5.4
            case .unitedKingdom:    return 4.0
            case .continentalEurope:return 3.3
            case .oceania:          return 5.2
            case .globalAverage:    return 4.1
            }
        case .food:
            switch region {
            case .northAmerica:     return 3.3
            case .unitedKingdom:    return 2.8
            case .continentalEurope:return 2.6
            case .oceania:          return 3.0
            case .globalAverage:    return 2.8
            }
        case .shopping:
            switch region {
            case .northAmerica:     return 2.3
            case .unitedKingdom:    return 1.8
            case .continentalEurope:return 1.6
            case .oceania:          return 2.0
            case .globalAverage:    return 1.8
            }
        case .other:
            switch region {
            case .northAmerica:     return 1.2
            case .unitedKingdom:    return 0.9
            case .continentalEurope:return 0.8
            case .oceania:          return 1.1
            case .globalAverage:    return 0.9
            }
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

    /// Default emission factor in kg CO₂e per km for the global average.
    var kgPerKm: Double {
        kgPerKm(in: .globalAverage)
    }

    func kgPerKm(in region: CarbonRegion) -> Double {
        switch self {
        case .walking, .cycling, .running:
            return 0.0
        case .car:
            switch region {
            case .northAmerica:     return 0.251
            case .unitedKingdom:    return 0.171
            case .continentalEurope:return 0.156
            case .oceania:          return 0.214
            case .globalAverage:    return 0.192
            }
        case .publicTransport:
            switch region {
            case .northAmerica:     return 0.104
            case .unitedKingdom:    return 0.089
            case .continentalEurope:return 0.071
            case .oceania:          return 0.096
            case .globalAverage:    return 0.090
            }
        case .flight:
            switch region {
            case .northAmerica:     return 0.245
            case .unitedKingdom:    return 0.255
            case .continentalEurope:return 0.230
            case .oceania:          return 0.270
            case .globalAverage:    return 0.248
            }
        case .ferry:
            switch region {
            case .northAmerica:     return 0.140
            case .unitedKingdom:    return 0.113
            case .continentalEurope:return 0.102
            case .oceania:          return 0.125
            case .globalAverage:    return 0.118
            }
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

    var isSavingEntry: Bool {
        kgCO2 < 0
    }

    var absoluteKgCO2: Double {
        abs(kgCO2)
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
