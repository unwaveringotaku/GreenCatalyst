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

    /// Daily food CO₂ baseline in kg
    var dailyFoodBaseline: Double {
        switch self {
        case .omnivore:    return 7.19
        case .flexitarian: return 5.50
        case .vegetarian:  return 3.81
        case .vegan:       return 2.89
        }
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
            dietaryPreference: .flexitarian
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
