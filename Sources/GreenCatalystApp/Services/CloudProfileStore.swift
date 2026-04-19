import Foundation

// MARK: - ProfileBackup

/// Lightweight struct for transferring restored profile data.
struct ProfileBackup {
    let name: String
    let email: String?
    let dietaryPreference: DietaryPreference
    let targetKgPerDay: Double
    let appleUserID: String?
}

// MARK: - CloudProfileStore

/// Backs up essential user profile fields to iCloud Key-Value Store
/// so they survive app reinstalls on the same Apple ID.
@MainActor
final class CloudProfileStore {

    static let shared = CloudProfileStore()

    private let kvStore = NSUbiquitousKeyValueStore.default

    // Keys
    private let profileDataKey = "userProfileData"
    private let appleUserIDKey = "appleUserIdentifier"

    // MARK: - Backup

    func backupProfile(_ profile: UserProfile, appleUserID: String?) {
        let payload: [String: Any] = [
            "name": profile.name,
            "email": profile.email ?? "",
            "dietaryPreference": profile.dietaryPreference.rawValue,
            "targetKgPerDay": profile.targetKgPerDay,
            "hasCompletedOnboarding": profile.hasCompletedOnboarding
        ]
        kvStore.set(payload, forKey: profileDataKey)
        if let appleUserID {
            kvStore.set(appleUserID, forKey: appleUserIDKey)
        }
        kvStore.synchronize()
    }

    // MARK: - Restore

    func restoreProfile() -> ProfileBackup? {
        kvStore.synchronize()

        guard let payload = kvStore.dictionary(forKey: profileDataKey),
              let name = payload["name"] as? String,
              let hasCompleted = payload["hasCompletedOnboarding"] as? Bool,
              hasCompleted else {
            return nil
        }

        return ProfileBackup(
            name: name,
            email: (payload["email"] as? String).flatMap { $0.isEmpty ? nil : $0 },
            dietaryPreference: (payload["dietaryPreference"] as? String)
                .flatMap { DietaryPreference(rawValue: $0) } ?? .omnivore,
            targetKgPerDay: payload["targetKgPerDay"] as? Double ?? 8.0,
            appleUserID: kvStore.string(forKey: appleUserIDKey)
        )
    }

    var storedAppleUserID: String? {
        kvStore.string(forKey: appleUserIDKey)
    }
}
