import Foundation
import SwiftData

// MARK: - PermissionStatus

enum PermissionStatus: String, Codable {
    case notDetermined = "Not Determined"
    case granted       = "Granted"
    case denied        = "Denied"
    case restricted    = "Restricted"
}

// MARK: - GrantedPermissions

struct GrantedPermissions: Codable {
    var healthKit: PermissionStatus
    var location: PermissionStatus
    var notifications: PermissionStatus

    init(
        healthKit: PermissionStatus = .notDetermined,
        location: PermissionStatus = .notDetermined,
        notifications: PermissionStatus = .notDetermined
    ) {
        self.healthKit = healthKit
        self.location = location
        self.notifications = notifications
    }

    var allGranted: Bool {
        healthKit == .granted && location == .granted && notifications == .granted
    }
}

// MARK: - DietaryPreference

enum DietaryPreference: String, Codable, CaseIterable {
    case omnivore    = "Omnivore"
    case flexitarian = "Flexitarian"
    case vegetarian  = "Vegetarian"
    case vegan       = "Vegan"

    /// Daily food CO₂ baseline in kg for a neutral global average.
    var dailyFoodBaseline: Double {
        dailyFoodBaseline(in: .globalAverage)
    }

    func dailyFoodBaseline(in region: CarbonRegion) -> Double {
        let base: Double
        switch self {
        case .omnivore:    base = 7.19
        case .flexitarian: base = 5.50
        case .vegetarian:  base = 3.81
        case .vegan:       base = 2.89
        }

        return base * region.foodBaselineMultiplier
    }
}

// MARK: - CarbonRegion

enum CarbonRegionPreference: String, Codable, CaseIterable, Identifiable {
    case automatic = "Automatic"
    case northAmerica = "North America"
    case unitedKingdom = "United Kingdom"
    case continentalEurope = "Continental Europe"
    case oceania = "Oceania"
    case globalAverage = "Global Average"

    var id: String { rawValue }

    func resolved(for locale: Locale = .current) -> CarbonRegion {
        switch self {
        case .automatic:
            return CarbonRegion.from(locale: locale)
        case .northAmerica:
            return .northAmerica
        case .unitedKingdom:
            return .unitedKingdom
        case .continentalEurope:
            return .continentalEurope
        case .oceania:
            return .oceania
        case .globalAverage:
            return .globalAverage
        }
    }
}

enum CarbonRegion: String, Codable, CaseIterable, Identifiable {
    case northAmerica
    case unitedKingdom
    case continentalEurope
    case oceania
    case globalAverage

    var id: String { rawValue }

    static func from(locale: Locale) -> CarbonRegion {
        switch locale.region?.identifier {
        case "US", "CA", "MX":
            return .northAmerica
        case "GB":
            return .unitedKingdom
        case "AU", "NZ":
            return .oceania
        case "AT", "BE", "BG", "CH", "CY", "CZ", "DE", "DK", "EE", "ES", "FI", "FR", "GR", "HR", "HU", "IE", "IS", "IT", "LT", "LU", "LV", "MT", "NL", "NO", "PL", "PT", "RO", "SE", "SI", "SK":
            return .continentalEurope
        default:
            return .globalAverage
        }
    }

    var displayName: String {
        switch self {
        case .northAmerica:
            return "North America"
        case .unitedKingdom:
            return "United Kingdom"
        case .continentalEurope:
            return "Continental Europe"
        case .oceania:
            return "Oceania"
        case .globalAverage:
            return "Global Average"
        }
    }

    var currencyCode: String {
        switch self {
        case .northAmerica:
            return "USD"
        case .unitedKingdom:
            return "GBP"
        case .continentalEurope:
            return "EUR"
        case .oceania:
            return "AUD"
        case .globalAverage:
            return Locale.current.currency?.identifier ?? "USD"
        }
    }

    var distanceUnit: UnitLength {
        switch self {
        case .northAmerica, .unitedKingdom:
            return .miles
        case .continentalEurope, .oceania, .globalAverage:
            return .kilometers
        }
    }

    var electricityKgPerKWh: Double {
        switch self {
        case .northAmerica:
            return 0.38
        case .unitedKingdom:
            return 0.23
        case .continentalEurope:
            return 0.19
        case .oceania:
            return 0.68
        case .globalAverage:
            return 0.44
        }
    }

    var gasKgPerKWh: Double {
        switch self {
        case .northAmerica:
            return 0.18
        case .unitedKingdom:
            return 0.20
        case .continentalEurope:
            return 0.19
        case .oceania:
            return 0.21
        case .globalAverage:
            return 0.20
        }
    }

    var foodBaselineMultiplier: Double {
        switch self {
        case .northAmerica:
            return 1.08
        case .unitedKingdom:
            return 1.00
        case .continentalEurope:
            return 0.95
        case .oceania:
            return 1.04
        case .globalAverage:
            return 1.00
        }
    }

    var shoppingSpendMultiplier: Double {
        switch self {
        case .northAmerica:
            return 0.90
        case .unitedKingdom:
            return 1.00
        case .continentalEurope:
            return 0.94
        case .oceania:
            return 0.98
        case .globalAverage:
            return 0.96
        }
    }

    var recommendedDailyTargetKg: Double {
        switch self {
        case .northAmerica:
            return 12.0
        case .unitedKingdom:
            return 8.0
        case .continentalEurope:
            return 7.0
        case .oceania:
            return 11.0
        case .globalAverage:
            return 8.0
        }
    }

    var averageDailyFootprintText: String {
        String(format: "%.0f kg CO₂", recommendedDailyTargetKg)
    }
}

// MARK: - UserProfile

/// The authenticated user's profile and preferences. Stored via SwiftData.
@Model
final class UserProfile: Identifiable {
    var id: UUID
    var name: String
    var email: String?
    var avatarSystemIcon: String
    var joinDate: Date
    var targetKgPerDay: Double           // personal daily CO₂ budget
    var locationCity: String?
    var dietaryPreference: DietaryPreference
    var regionPreference: CarbonRegionPreference
    var permissions: GrantedPermissions
    var hasCompletedOnboarding: Bool
    var weeklyEmailEnabled: Bool
    var notificationEnabled: Bool

    // Apple ID
    var appleUserIdentifier: String?

    // Gamification
    var totalPoints: Int
    var level: Int
    var badges: [String]                 // badge identifiers

    init(
        id: UUID = UUID(),
        name: String = "Green Explorer",
        email: String? = nil,
        avatarSystemIcon: String = "person.circle.fill",
        targetKgPerDay: Double = 8.0,
        locationCity: String? = nil,
        dietaryPreference: DietaryPreference = .omnivore,
        regionPreference: CarbonRegionPreference = .automatic,
        appleUserIdentifier: String? = nil
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.avatarSystemIcon = avatarSystemIcon
        self.joinDate = .now
        self.targetKgPerDay = targetKgPerDay
        self.locationCity = locationCity
        self.dietaryPreference = dietaryPreference
        self.regionPreference = regionPreference
        self.appleUserIdentifier = appleUserIdentifier
        self.permissions = GrantedPermissions()
        self.hasCompletedOnboarding = false
        self.weeklyEmailEnabled = true
        self.notificationEnabled = true
        self.totalPoints = 0
        self.level = 1
        self.badges = []
    }

    // MARK: - Computed

    var levelTitle: String {
        switch level {
        case 1:     return "Seedling"
        case 2:     return "Sprout"
        case 3:     return "Sapling"
        case 4:     return "Tree"
        case 5...7: return "Forest Guardian"
        default:    return "Carbon Champion"
        }
    }

    var pointsToNextLevel: Int {
        let thresholds = [0, 100, 300, 600, 1000, 1500, 2200, 3000]
        guard level < thresholds.count else { return 0 }
        return thresholds[level] - totalPoints
    }

    var resolvedRegion: CarbonRegion {
        regionPreference.resolved()
    }

    var currencyCode: String {
        resolvedRegion.currencyCode
    }

    var distanceUnitLabel: String {
        DisplayFormatting.distanceUnitLabel(for: resolvedRegion)
    }

    func addPoints(_ points: Int) {
        totalPoints += points
        // Level up thresholds
        let thresholds = [0, 100, 300, 600, 1000, 1500, 2200, 3000]
        for (index, threshold) in thresholds.enumerated() {
            if totalPoints >= threshold { level = index + 1 }
        }
    }
}

// MARK: - Equatable

extension UserProfile: Equatable {
    static func == (lhs: UserProfile, rhs: UserProfile) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Sample Data

extension UserProfile {
    static var sample: UserProfile {
        let profile = UserProfile(
            name: "Alex Green",
            email: "alex@example.com",
            targetKgPerDay: 8.0,
            locationCity: "London",
            dietaryPreference: .flexitarian,
            regionPreference: .unitedKingdom
        )
        profile.totalPoints = 240
        profile.level = 3
        profile.badges = ["first_week", "meat_free_month"]
        profile.hasCompletedOnboarding = true
        profile.permissions = GrantedPermissions(
            healthKit: .granted,
            location: .granted,
            notifications: .granted
        )
        return profile
    }
}

// MARK: - DisplayFormatting

enum DisplayFormatting {
    static func currency(_ amount: Double, currencyCode: String? = nil) -> String {
        let code = currencyCode ?? Locale.current.currency?.identifier ?? "USD"
        return amount.formatted(.currency(code: code))
    }

    static func distanceUnitLabel(for region: CarbonRegion) -> String {
        switch region.distanceUnit {
        case .miles:
            return "mi"
        default:
            return "km"
        }
    }

    static func distance(_ kilometers: Double, region: CarbonRegion) -> String {
        let measurement = Measurement(value: kilometers, unit: UnitLength.kilometers)
            .converted(to: region.distanceUnit)
        let formatStyle = Measurement<UnitLength>.FormatStyle(
            width: .abbreviated,
            usage: .road,
            numberFormatStyle: .number.precision(.fractionLength(0...1))
        )
        return measurement.formatted(formatStyle)
    }

    static func distanceValue(_ kilometers: Double, region: CarbonRegion) -> String {
        let measurement = Measurement(value: kilometers, unit: UnitLength.kilometers)
            .converted(to: region.distanceUnit)
        return measurement.value.formatted(.number.precision(.fractionLength(0...1)))
    }

    static func kilometers(from localizedDistance: String, region: CarbonRegion) -> Double? {
        guard let value = Double(localizedDistance) else { return nil }
        let measurement = Measurement(value: value, unit: region.distanceUnit)
            .converted(to: .kilometers)
        return measurement.value
    }

    static func carbon(_ amount: Double) -> String {
        String(format: "%.1f kg CO₂", amount)
    }

    static func carbonValue(_ amount: Double) -> String {
        String(format: "%.1f", amount)
    }
}
