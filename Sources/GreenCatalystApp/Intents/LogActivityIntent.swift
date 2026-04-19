import AppIntents
import Foundation

// MARK: - ActivityType

enum ActivityType: String, AppEnum {
    case bikeCommute     = "Bike Commute"
    case walkCommute     = "Walk Commute"
    case carCommute      = "Car Commute"
    case publicTransport = "Public Transport"
    case meatFreeMeal    = "Meat-Free Meal"
    case shortShower     = "Short Shower"
    case energySaving    = "Energy Saving"
    case recycling       = "Recycling"

    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Activity Type" }
    static var caseDisplayRepresentations: [ActivityType: DisplayRepresentation] {
        [
            .bikeCommute: "Bike Commute",
            .walkCommute: "Walk Commute",
            .carCommute: "Car Commute",
            .publicTransport: "Public Transport",
            .meatFreeMeal: "Meat-Free Meal",
            .shortShower: "Short Shower",
            .energySaving: "Energy Saving",
            .recycling: "Recycling",
        ]
    }

    var carbonCategory: CarbonCategory {
        switch self {
        case .bikeCommute, .walkCommute, .carCommute, .publicTransport: return .transport
        case .meatFreeMeal:                                              return .food
        case .shortShower, .energySaving:                               return .energy
        case .recycling:                                                 return .shopping
        }
    }

    func kgCO2(distanceKm: Double) -> Double {
        let calc = CarbonCalculator()
        switch self {
        case .bikeCommute:     return 0   // zero emissions
        case .walkCommute:     return 0
        case .carCommute:      return calc.calculateTransport(mode: .car, distanceKm: distanceKm)
        case .publicTransport: return calc.calculateTransport(mode: .publicTransport, distanceKm: distanceKm)
        case .meatFreeMeal:    return 1.8  // average saving per plant-based meal
        case .shortShower:     return 0.4
        case .energySaving:    return 0.5
        case .recycling:       return 0.2
        }
    }
}

// MARK: - LogActivityIntent

struct LogActivityIntent: AppIntent {

    static var title: LocalizedStringResource { "Log Activity" }
    static var description: IntentDescription {
        IntentDescription(
            "Logs a carbon-related activity to GreenCatalyst.",
            categoryName: "Carbon Tracking"
        )
    }

    // Siri phrases
    static var openAppWhenRun: Bool { false }

    @Parameter(title: "Activity Type", description: "What kind of activity did you do?")
    var activityType: ActivityType

    @Parameter(
        title: "Distance (km)",
        description: "How far did you travel? (Only needed for commute activities)",
        default: 0.0,
        controlStyle: .field,
        inclusiveRange: (0.0, 500.0)
    )
    var distanceKm: Double

    @Parameter(title: "Notes", description: "Optional notes about this activity")
    var notes: String?

    // MARK: - Perform

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let kg = activityType.kgCO2(distanceKm: distanceKm)
        let entry = CarbonEntry(
            category: activityType.carbonCategory,
            kgCO2: kg,
            source: .manual,
            notes: notes ?? activityType.rawValue,
            transportMode: transportMode,
            distanceKm: distanceKm > 0 ? distanceKm : nil
        )

        try await MainActor.run {
            let store = DataStore.shared
            store.saveEntrySync(entry)
            try store.saveContext()
        }

        let dialog: IntentDialog
        if kg == 0 {
            dialog = IntentDialog(
                full: "Logged! Great choice — \(activityType.rawValue) produces zero emissions. Keep it up! 🌿",
                supporting: "Zero-emission activity logged."
            )
        } else {
            dialog = IntentDialog(
                full: "Logged \(activityType.rawValue). That's \(String(format: "%.1f", kg)) kg CO₂. \(motivationalSuffix(kg))",
                supporting: "\(String(format: "%.1f", kg)) kg CO₂ logged."
            )
        }

        return .result(dialog: dialog)
    }

    // MARK: - Helpers

    private var transportMode: TransportMode? {
        switch activityType {
        case .bikeCommute:     return .cycling
        case .walkCommute:     return .walking
        case .carCommute:      return .car
        case .publicTransport: return .publicTransport
        default:               return nil
        }
    }

    private func motivationalSuffix(_ kg: Double) -> String {
        if kg < 2.0 { return "Nice, you're well under target! 🎉" }
        if kg < 5.0 { return "You're on track today. 👍" }
        return "Consider a greener option next time. 🌱"
    }
}

// MARK: - Shortcuts Provider

struct GreenCatalystShortcuts: AppShortcutsProvider {
    @AppShortcutsBuilder
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogActivityIntent(),
            phrases: [
                "Log my \(\.$activityType) in \(.applicationName)",
                "Log \(\.$activityType) commute in \(.applicationName)",
                "Record my \(\.$activityType) in \(.applicationName)",
            ],
            shortTitle: "Log Activity",
            systemImageName: "plus.circle.fill"
        )
        AppShortcut(
            intent: GetCarbonScoreIntent(),
            phrases: [
                "What's my carbon score in \(.applicationName)",
                "How much CO2 have I used in \(.applicationName)",
                "My carbon footprint today in \(.applicationName)",
            ],
            shortTitle: "Carbon Score",
            systemImageName: "chart.line.uptrend.xyaxis.circle.fill"
        )
    }
}
