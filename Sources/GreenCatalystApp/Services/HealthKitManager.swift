import Foundation
import HealthKit

// MARK: - HealthKitError

enum HealthKitError: LocalizedError {
    case notAvailable
    case permissionDenied
    case queryFailed(Error)

    var errorDescription: String? {
        switch self {
        case .notAvailable:      return "HealthKit is not available on this device."
        case .permissionDenied:  return "HealthKit permission was denied. Enable it in Settings > Health > GreenCatalyst."
        case .queryFailed(let e): return "HealthKit query failed: \(e.localizedDescription)"
        }
    }
}

// MARK: - HealthKitManager

/// Singleton wrapper around HKHealthStore. Requests permissions, fetches workouts
/// and step data, and infers carbon-relevant transport modes.
@MainActor
final class HealthKitManager: ObservableObject {

    static let shared = HealthKitManager()

    private let store = HKHealthStore()
    private let calculator = CarbonCalculator()

    // MARK: - Published

    @Published var isAuthorized: Bool = false
    @Published var todaySteps: Int = 0
    @Published var todayActiveCalories: Double = 0

    // MARK: - HealthKit Types

    private var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = []
        if let steps = HKQuantityType.quantityType(forIdentifier: .stepCount) {
            types.insert(steps)
        }
        if let calories = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            types.insert(calories)
        }
        if let distance = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) {
            types.insert(distance)
        }
        if let cycling = HKQuantityType.quantityType(forIdentifier: .distanceCycling) {
            types.insert(cycling)
        }
        types.insert(HKObjectType.workoutType())
        return types
    }

    private var writeTypes: Set<HKSampleType> {
        guard let cycling = HKQuantityType.quantityType(forIdentifier: .distanceCycling) else {
            return []
        }
        return [cycling]
    }

    // MARK: - Authorization

    func requestAuthorization() async {
        guard !isAuthorized, HKHealthStore.isHealthDataAvailable() else { return }
        do {
            try await store.requestAuthorization(toShare: writeTypes, read: readTypes)
            isAuthorized = true
        } catch {
            isAuthorized = false
        }
    }

    // MARK: - Queries

    /// Fetch today's step count.
    func fetchTodaySteps() async throws -> Int {
        guard HKHealthStore.isHealthDataAvailable() else { throw HealthKitError.notAvailable }
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            throw HealthKitError.notAvailable
        }
        let predicate = HKQuery.predicateForSamples(
            withStart: Calendar.current.startOfDay(for: .now),
            end: .now
        )
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, stats, error in
                if let error = error {
                    continuation.resume(throwing: HealthKitError.queryFailed(error))
                    return
                }
                let steps = Int(stats?.sumQuantity()?.doubleValue(for: .count()) ?? 0)
                continuation.resume(returning: steps)
            }
            store.execute(query)
        }
    }

    /// Fetch cycling distance today (km).
    func fetchTodayCyclingKm() async throws -> Double {
        guard let cycleType = HKQuantityType.quantityType(forIdentifier: .distanceCycling) else {
            return 0
        }
        let predicate = HKQuery.predicateForSamples(
            withStart: Calendar.current.startOfDay(for: .now),
            end: .now
        )
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: cycleType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, stats, error in
                if let error = error {
                    continuation.resume(throwing: HealthKitError.queryFailed(error))
                    return
                }
                let meters = stats?.sumQuantity()?.doubleValue(for: .meter()) ?? 0
                continuation.resume(returning: meters / 1000.0)
            }
            store.execute(query)
        }
    }

    /// Fetch workouts for a given date range.
    func fetchWorkouts(from start: Date, to end: Date) async throws -> [HKWorkout] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: HealthKitError.queryFailed(error))
                    return
                }
                continuation.resume(returning: (samples as? [HKWorkout]) ?? [])
            }
            store.execute(query)
        }
    }

    // MARK: - Transport Inference

    /// Infer carbon entries from today's HealthKit data.
    func inferCarbonEntries(for date: Date) async throws -> [CarbonEntry] {
        let start = Calendar.current.startOfDay(for: date)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? date

        let workouts = try await fetchWorkouts(from: start, to: end)
        var entries: [CarbonEntry] = []

        for workout in workouts {
            guard let mode = transportMode(from: workout) else { continue }
            let distanceM = workout.totalDistance?.doubleValue(for: .meter()) ?? 0
            let distanceKm = distanceM / 1000.0
            guard distanceKm > 0.1 else { continue }

            let kg = calculator.calculateTransport(mode: mode, distanceKm: distanceKm)

            // Only log non-zero emissions (cycling/walking = 0 but still worthwhile as saved)
            let entry = CarbonEntry(
                date: workout.startDate,
                category: .transport,
                kgCO2: kg,
                source: .healthKit,
                notes: "Auto-detected \(mode.rawValue) (\(String(format: "%.1f", distanceKm)) km) from HealthKit",
                transportMode: mode,
                distanceKm: distanceKm,
                isVerified: true
            )
            entries.append(entry)
        }

        return entries
    }

    // MARK: - Mode Inference

    private func transportMode(from workout: HKWorkout) -> TransportMode? {
        switch workout.workoutActivityType {
        case .walking:         return .walking
        case .running:         return .running
        case .cycling:         return .cycling
        case .other:           return inferFromMetrics(workout)
        default:               return nil
        }
    }

    private func inferFromMetrics(_ workout: HKWorkout) -> TransportMode? {
        // Use speed as a heuristic: >30 km/h average → car
        let distanceM = workout.totalDistance?.doubleValue(for: .meter()) ?? 0
        let duration = workout.duration
        guard duration > 0, distanceM > 0 else { return nil }
        let speedKmH = (distanceM / duration) * 3.6
        if speedKmH > 30 { return .car }
        if speedKmH > 15 { return .cycling }
        return .walking
    }
}
