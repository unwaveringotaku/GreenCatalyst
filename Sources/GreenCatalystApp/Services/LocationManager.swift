import CoreLocation
import Foundation
import Observation

// MARK: - TripState

enum TripState: Equatable {
    case idle
    case detectingStart
    case inProgress(startLocation: CLLocation, startTime: Date)
    case ended(distanceKm: Double, mode: TransportMode)
}

// MARK: - LocationError

enum LocationError: LocalizedError {
    case permissionDenied
    case permissionRestricted
    case locationUnknown

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Location access denied. Enable Always Allow in Settings to detect trips in the background."
        case .permissionRestricted:
            return "Location access is restricted on this device."
        case .locationUnknown:
            return "Could not determine your location."
        }
    }
}

// MARK: - DetectedCommute

struct DetectedCommute: Identifiable, Equatable {
    let id: UUID
    let date: Date
    let distanceKm: Double
    let mode: TransportMode
    let summary: String

    init(
        id: UUID = UUID(),
        date: Date,
        distanceKm: Double,
        mode: TransportMode,
        summary: String
    ) {
        self.id = id
        self.date = date
        self.distanceKm = distanceKm
        self.mode = mode
        self.summary = summary
    }
}

private enum RoutinePlaceKind: String, Codable {
    case home
    case work
    case other

    var displayName: String {
        rawValue.capitalized
    }
}

private struct StoredVisit: Codable {
    let latitude: Double
    let longitude: Double
    let arrivalDate: Date
    let departureDate: Date

    var location: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }

    init(location: CLLocation, arrivalDate: Date, departureDate: Date) {
        self.latitude = location.coordinate.latitude
        self.longitude = location.coordinate.longitude
        self.arrivalDate = arrivalDate
        self.departureDate = departureDate
    }
}

private struct RoutinePlace: Codable, Identifiable {
    let id: UUID
    var latitude: Double
    var longitude: Double
    var visitCount: Int
    var homeScore: Double
    var workScore: Double
    var lastVisitedAt: Date

    init(
        id: UUID = UUID(),
        latitude: Double,
        longitude: Double,
        visitCount: Int = 1,
        homeScore: Double = 0,
        workScore: Double = 0,
        lastVisitedAt: Date
    ) {
        self.id = id
        self.latitude = latitude
        self.longitude = longitude
        self.visitCount = visitCount
        self.homeScore = homeScore
        self.workScore = workScore
        self.lastVisitedAt = lastVisitedAt
    }

    var location: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }

    var kind: RoutinePlaceKind {
        if homeScore >= 3, homeScore > workScore * 1.2 {
            return .home
        }

        if workScore >= 3, workScore > homeScore * 1.1 {
            return .work
        }

        return .other
    }

    mutating func absorb(location: CLLocation, visitedAt: Date, isHomeLike: Bool, isWorkLike: Bool) {
        let total = Double(visitCount)
        latitude = ((latitude * total) + location.coordinate.latitude) / (total + 1)
        longitude = ((longitude * total) + location.coordinate.longitude) / (total + 1)
        visitCount += 1
        if isHomeLike { homeScore += 1 }
        if isWorkLike { workScore += 1 }
        lastVisitedAt = visitedAt
    }
}

// MARK: - LocationManager

/// Passive commute detection built on visits and significant location changes.
/// Logged trips are explicitly marked as estimated and avoid counterfactual savings.
@MainActor
@Observable
final class LocationManager: NSObject {

    static let shared = LocationManager()

    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    var currentLocation: CLLocation? = nil
    var tripState: TripState = .idle
    var errorMessage: String? = nil
    var isMonitoringPassively: Bool = false
    var lastDetectedCommute: DetectedCommute? = nil
    var routinePlaceSummary: String = "Learning commute patterns"

    private let clManager = CLLocationManager()
    private let calculator = CarbonCalculator()
    private let dataStore: DataStore
    private let notificationCenter: NotificationCenter
    private let defaults: UserDefaults

    private var tripPath: [CLLocation] = []
    private var stationarySince: Date? = nil
    private var lastStationaryVisit: StoredVisit? = nil
    private var routinePlaces: [RoutinePlace] = []

    private let tripStartDistanceThreshold: CLLocationDistance = 500
    private let tripEndStateDuration: TimeInterval = 120
    private let minimumTripDistanceKm: Double = 1.0
    private let maximumTripDuration: TimeInterval = 4 * 60 * 60
    private let routinePlaceRadius: CLLocationDistance = 300
    private let routinePlacesKey = "GreenCatalyst.location.routinePlaces"
    private let lastVisitKey = "GreenCatalyst.location.lastVisit"

    init(
        dataStore: DataStore = .shared,
        notificationCenter: NotificationCenter = .default,
        defaults: UserDefaults = .standard
    ) {
        self.dataStore = dataStore
        self.notificationCenter = notificationCenter
        self.defaults = defaults
        super.init()

        clManager.delegate = self
        clManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        clManager.distanceFilter = 50
        clManager.pausesLocationUpdatesAutomatically = true
        clManager.activityType = .otherNavigation
        clManager.allowsBackgroundLocationUpdates = true
        clManager.showsBackgroundLocationIndicator = false

        authorizationStatus = clManager.authorizationStatus
        loadPersistedState()
        refreshRoutineSummary()
    }

    // MARK: - Authorization

    func refreshAuthorizationStatus() {
        authorizationStatus = clManager.authorizationStatus
    }

    func requestPassiveCommutePermission() {
        refreshAuthorizationStatus()

        switch authorizationStatus {
        case .notDetermined:
            clManager.requestAlwaysAuthorization()
        case .authorizedWhenInUse:
            clManager.requestAlwaysAuthorization()
        case .authorizedAlways:
            startPassiveMonitoring()
        case .denied:
            errorMessage = LocationError.permissionDenied.errorDescription
        case .restricted:
            errorMessage = LocationError.permissionRestricted.errorDescription
        @unknown default:
            break
        }
    }

    // MARK: - Monitoring

    func startPassiveMonitoring() {
        refreshAuthorizationStatus()
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            isMonitoringPassively = false
            return
        }

        isMonitoringPassively = true
        clManager.startMonitoringVisits()
        clManager.startMonitoringSignificantLocationChanges()
        clManager.requestLocation()
    }

    func stopPassiveMonitoring() {
        isMonitoringPassively = false
        clManager.stopMonitoringVisits()
        clManager.stopMonitoringSignificantLocationChanges()
        stopActiveTripTracking()
    }

    // MARK: - Trip Calculation

    var currentTripDistanceKm: Double {
        guard tripPath.count >= 2 else { return 0 }

        var total: Double = 0
        for index in 1..<tripPath.count {
            total += tripPath[index].distance(from: tripPath[index - 1])
        }

        return total / 1000.0
    }

    private func startDetectedTrip(from anchorVisit: StoredVisit, with location: CLLocation) {
        guard tripState == .idle else { return }

        tripPath = [anchorVisit.location, location]
        stationarySince = nil
        tripState = .inProgress(startLocation: anchorVisit.location, startTime: anchorVisit.departureDate)

        clManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        clManager.distanceFilter = 20
        clManager.startUpdatingLocation()
    }

    private func stopActiveTripTracking() {
        clManager.stopUpdatingLocation()
        clManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        clManager.distanceFilter = 50
        tripPath.removeAll()
        stationarySince = nil
        if case .inProgress = tripState {
            tripState = .idle
        }
    }

    private func completeTrip(with endLocation: CLLocation, at endDate: Date) {
        guard case .inProgress(let startLocation, let startTime) = tripState else { return }

        tripPath.append(endLocation)
        let trackedDistanceKm = currentTripDistanceKm
        let directDistanceKm = startLocation.distance(from: endLocation) / 1000.0
        let distanceKm = max(trackedDistanceKm, directDistanceKm)

        defer {
            stopActiveTripTracking()
        }

        guard distanceKm >= minimumTripDistanceKm else { return }
        guard endDate.timeIntervalSince(startTime) <= maximumTripDuration else { return }

        let mode = inferredMode(distanceKm: distanceKm, startTime: startTime, endTime: endDate)
        guard isLikelyCommute(
            startLocation: startLocation,
            endLocation: endLocation,
            startTime: startTime,
            endTime: endDate,
            distanceKm: distanceKm
        ) else {
            tripState = .idle
            return
        }

        tripState = .ended(distanceKm: distanceKm, mode: mode)

        Task {
            do {
                let profile = try await dataStore.fetchUserProfile()
                let region = profile.resolvedRegion
                let startPlace = nearestRoutinePlace(to: startLocation)
                let endPlace = nearestRoutinePlace(to: endLocation)
                let notes = commuteSummary(
                    mode: mode,
                    distanceKm: distanceKm,
                    region: region,
                    startPlace: startPlace,
                    endPlace: endPlace,
                    startTime: startTime
                )
                let kgCO2 = calculator.calculateTransport(mode: mode, distanceKm: distanceKm, region: region)
                let entry = CarbonEntry(
                    date: endDate,
                    category: .transport,
                    kgCO2: kgCO2,
                    source: .location,
                    notes: notes,
                    transportMode: mode,
                    distanceKm: distanceKm,
                    isVerified: false
                )

                let wasSaved = try await dataStore.saveEntryIfNeeded(entry)
                if wasSaved {
                    lastDetectedCommute = DetectedCommute(
                        date: endDate,
                        distanceKm: distanceKm,
                        mode: mode,
                        summary: notes
                    )
                    notificationCenter.post(name: .carbonDataDidChange, object: nil)
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }

            await MainActor.run {
                tripState = .idle
            }
        }
    }

    private func inferredMode(distanceKm: Double, startTime: Date, endTime: Date) -> TransportMode {
        let durationHours = max(endTime.timeIntervalSince(startTime) / 3600.0, 0.01)
        let averageKmPerHour = distanceKm / durationHours

        if averageKmPerHour >= 28 {
            return .car
        }

        if averageKmPerHour >= 16 {
            return distanceKm >= 4 ? .publicTransport : .cycling
        }

        if averageKmPerHour >= 8 {
            return .cycling
        }

        return .walking
    }

    private func isLikelyCommute(
        startLocation: CLLocation,
        endLocation: CLLocation,
        startTime: Date,
        endTime: Date,
        distanceKm: Double
    ) -> Bool {
        guard isWeekday(startTime), isWeekday(endTime) else { return false }
        guard (1.0...60.0).contains(distanceKm) else { return false }

        let startPlace = nearestRoutinePlace(to: startLocation)
        let endPlace = nearestRoutinePlace(to: endLocation)
        let hasRoutinePair = {
            guard let startKind = startPlace?.kind, let endKind = endPlace?.kind else { return false }
            return (startKind == .home && endKind == .work) || (startKind == .work && endKind == .home)
        }()

        return hasRoutinePair || isCommuteWindow(startTime)
    }

    private func commuteSummary(
        mode: TransportMode,
        distanceKm: Double,
        region: CarbonRegion,
        startPlace: RoutinePlace?,
        endPlace: RoutinePlace?,
        startTime: Date
    ) -> String {
        let routeLabel: String

        if let startPlace, let endPlace, startPlace.kind != .other || endPlace.kind != .other {
            routeLabel = "Estimated \(startPlace.kind.displayName.lowercased()) to \(endPlace.kind.displayName.lowercased()) commute"
        } else if isMorningCommute(startTime) {
            routeLabel = "Estimated morning commute"
        } else if isEveningCommute(startTime) {
            routeLabel = "Estimated evening commute"
        } else {
            routeLabel = "Estimated commute"
        }

        return "\(routeLabel) by \(mode.rawValue.lowercased()) (\(DisplayFormatting.distance(distanceKm, region: region)))."
    }

    // MARK: - Routine Place Learning

    private func updateRoutinePlaces(location: CLLocation, visitedAt: Date) {
        let arrival = visitedAt
        let homeLike = isHomeLike(visitDate: arrival)
        let workLike = isWorkLike(visitDate: arrival)

        if let index = nearestRoutinePlaceIndex(to: location) {
            routinePlaces[index].absorb(
                location: location,
                visitedAt: arrival,
                isHomeLike: homeLike,
                isWorkLike: workLike
            )
        } else {
            routinePlaces.append(
                RoutinePlace(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude,
                    homeScore: homeLike ? 1 : 0,
                    workScore: workLike ? 1 : 0,
                    lastVisitedAt: arrival
                )
            )
        }

        persistRoutinePlaces()
        refreshRoutineSummary()
    }

    private func nearestRoutinePlace(to location: CLLocation) -> RoutinePlace? {
        guard let index = nearestRoutinePlaceIndex(to: location) else { return nil }
        return routinePlaces[index]
    }

    private func nearestRoutinePlaceIndex(to location: CLLocation) -> Int? {
        routinePlaces.enumerated()
            .filter { $0.element.location.distance(from: location) <= routinePlaceRadius }
            .min { lhs, rhs in
                lhs.element.location.distance(from: location) < rhs.element.location.distance(from: location)
            }?
            .offset
    }

    private func refreshRoutineSummary() {
        let homeVisits = routinePlaces.filter { $0.kind == .home }.count
        let workVisits = routinePlaces.filter { $0.kind == .work }.count

        if homeVisits == 0 && workVisits == 0 {
            routinePlaceSummary = "Learning commute patterns"
        } else if workVisits == 0 {
            routinePlaceSummary = "Home area learned"
        } else if homeVisits == 0 {
            routinePlaceSummary = "Work area learned"
        } else {
            routinePlaceSummary = "Home and work areas learned"
        }
    }

    // MARK: - Persistence

    private func loadPersistedState() {
        if let data = defaults.data(forKey: routinePlacesKey),
           let decoded = try? JSONDecoder().decode([RoutinePlace].self, from: data) {
            routinePlaces = decoded
        }

        if let data = defaults.data(forKey: lastVisitKey),
           let decoded = try? JSONDecoder().decode(StoredVisit.self, from: data) {
            lastStationaryVisit = decoded
        }
    }

    private func persistRoutinePlaces() {
        if let data = try? JSONEncoder().encode(routinePlaces) {
            defaults.set(data, forKey: routinePlacesKey)
        }
    }

    private func persistLastStationaryVisit() {
        if let lastStationaryVisit,
           let data = try? JSONEncoder().encode(lastStationaryVisit) {
            defaults.set(data, forKey: lastVisitKey)
        } else {
            defaults.removeObject(forKey: lastVisitKey)
        }
    }

    // MARK: - Visit Helpers

    private func isHomeLike(visitDate: Date) -> Bool {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: visitDate)

        if !isWeekday(visitDate) {
            return true
        }

        return hour >= 19 || hour < 6
    }

    private func isWorkLike(visitDate: Date) -> Bool {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: visitDate)
        return isWeekday(visitDate) && (8..<18).contains(hour)
    }

    private func isWeekday(_ date: Date) -> Bool {
        !Calendar.current.isDateInWeekend(date)
    }

    private func isMorningCommute(_ date: Date) -> Bool {
        let hour = Calendar.current.component(.hour, from: date)
        return (5..<11).contains(hour)
    }

    private func isEveningCommute(_ date: Date) -> Bool {
        let hour = Calendar.current.component(.hour, from: date)
        return (15..<21).contains(hour)
    }

    private func isCommuteWindow(_ date: Date) -> Bool {
        isMorningCommute(date) || isEveningCommute(date)
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationManager: CLLocationManagerDelegate {

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            authorizationStatus = status

            switch status {
            case .authorizedAlways, .authorizedWhenInUse:
                startPassiveMonitoring()
            case .denied:
                errorMessage = LocationError.permissionDenied.errorDescription
            case .restricted:
                errorMessage = LocationError.permissionRestricted.errorDescription
            case .notDetermined:
                break
            @unknown default:
                break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        Task { @MainActor in
            currentLocation = location

            switch tripState {
            case .idle, .detectingStart:
                if let lastStationaryVisit,
                   location.distance(from: lastStationaryVisit.location) >= tripStartDistanceThreshold {
                    tripState = .detectingStart
                    startDetectedTrip(from: lastStationaryVisit, with: location)
                }

            case .inProgress(_, let startTime):
                tripPath.append(location)

                if location.speed >= 0.5 {
                    stationarySince = nil
                } else if stationarySince == nil {
                    stationarySince = location.timestamp
                }

                if let stationarySince,
                   location.timestamp.timeIntervalSince(stationarySince) >= tripEndStateDuration {
                    completeTrip(with: location, at: location.timestamp)
                } else if location.timestamp.timeIntervalSince(startTime) >= maximumTripDuration {
                    stopActiveTripTracking()
                }

            case .ended:
                tripState = .idle
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didVisit visit: CLVisit) {
        let coordinate = visit.coordinate
        let arrivalDate = visit.arrivalDate == .distantPast ? visit.departureDate : visit.arrivalDate
        let departureDate = visit.departureDate == .distantFuture ? arrivalDate : visit.departureDate

        Task { @MainActor in
            let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            currentLocation = location
            updateRoutinePlaces(location: location, visitedAt: arrivalDate)
            let storedVisit = StoredVisit(location: location, arrivalDate: arrivalDate, departureDate: departureDate)

            if case .inProgress = tripState {
                completeTrip(with: location, at: arrivalDate)
            }

            lastStationaryVisit = storedVisit
            persistLastStationaryVisit()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let message = error.localizedDescription
        Task { @MainActor in
            errorMessage = message
        }
    }
}
