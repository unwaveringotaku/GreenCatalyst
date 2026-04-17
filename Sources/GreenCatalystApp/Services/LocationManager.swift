import Foundation
import CoreLocation
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
    case geofenceLimit

    var errorDescription: String? {
        switch self {
        case .permissionDenied:    return "Location access denied. Enable it in Settings > Privacy > Location."
        case .permissionRestricted: return "Location access is restricted on this device."
        case .locationUnknown:     return "Could not determine your location."
        case .geofenceLimit:       return "Maximum number of geofences reached."
        }
    }
}

// MARK: - GeofenceZone

struct GeofenceZone: Identifiable, Codable {
    let id: UUID
    let name: String
    let coordinate: GCCoordinate
    let radiusMeters: Double
    let trigger: GeofenceTrigger

    init(id: UUID = UUID(), name: String, latitude: Double, longitude: Double, radiusMeters: Double, trigger: GeofenceTrigger = .entry) {
        self.id = id
        self.name = name
        self.coordinate = GCCoordinate(latitude: latitude, longitude: longitude)
        self.radiusMeters = radiusMeters
        self.trigger = trigger
    }
}

struct GCCoordinate: Codable {
    let latitude: Double
    let longitude: Double
}

enum GeofenceTrigger: String, Codable {
    case entry = "Entry"
    case exit  = "Exit"
    case both  = "Both"
}

// MARK: - LocationManager

/// CLLocationManager wrapper that detects trips, monitors geofences,
/// and publishes location updates to the rest of the app.
@Observable
final class LocationManager: NSObject, CLLocationManagerDelegate {

    static let shared = LocationManager()

    // MARK: - State

    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    var currentLocation: CLLocation? = nil
    var tripState: TripState = .idle
    var geofenceZones: [GeofenceZone] = []
    var lastTriggeredZone: GeofenceZone? = nil
    var errorMessage: String? = nil

    // MARK: - Private

    private let clManager = CLLocationManager()
    private let calculator = CarbonCalculator()
    private var tripPath: [CLLocation] = []

    // Trip detection thresholds
    private let tripStartSpeedThreshold: CLLocationSpeed = 2.0   // m/s ≈ 7 km/h
    private let tripEndStateDuration: TimeInterval = 120          // 2 min stationary to end trip
    private var stationarySince: Date? = nil

    override init() {
        super.init()
        clManager.delegate = self
        clManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        clManager.distanceFilter = 20
        clManager.pausesLocationUpdatesAutomatically = true
        clManager.activityType = .automotiveNavigation
    }

    // MARK: - Authorization

    func requestWhenInUsePermission() {
        clManager.requestWhenInUseAuthorization()
    }

    func requestAlwaysPermission() {
        clManager.requestAlwaysAuthorization()
    }

    // MARK: - Tracking

    func startTracking() {
        clManager.startUpdatingLocation()
    }

    func stopTracking() {
        clManager.stopUpdatingLocation()
        tripPath.removeAll()
        tripState = .idle
    }

    // MARK: - Geofencing

    func addGeofence(_ zone: GeofenceZone) throws {
        guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else {
            throw LocationError.geofenceLimit
        }
        let region = CLCircularRegion(
            center: CLLocationCoordinate2D(latitude: zone.coordinate.latitude, longitude: zone.coordinate.longitude),
            radius: zone.radiusMeters,
            identifier: zone.id.uuidString
        )
        region.notifyOnEntry = (zone.trigger == .entry || zone.trigger == .both)
        region.notifyOnExit  = (zone.trigger == .exit  || zone.trigger == .both)
        clManager.startMonitoring(for: region)
        geofenceZones.append(zone)
    }

    func removeGeofence(_ zone: GeofenceZone) {
        let regions = clManager.monitoredRegions.filter { $0.identifier == zone.id.uuidString }
        regions.forEach { clManager.stopMonitoring(for: $0) }
        geofenceZones.removeAll { $0.id == zone.id }
    }

    // MARK: - Trip Calculation

    var currentTripDistanceKm: Double {
        guard tripPath.count >= 2 else { return 0 }
        var total: Double = 0
        for i in 1..<tripPath.count {
            total += tripPath[i].distance(from: tripPath[i - 1])
        }
        return total / 1000.0
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location

        switch tripState {
        case .idle:
            if location.speed > tripStartSpeedThreshold {
                tripState = .detectingStart
                tripPath = [location]
            }
        case .detectingStart:
            tripPath.append(location)
            if location.speed > tripStartSpeedThreshold && tripPath.count >= 3 {
                tripState = .inProgress(startLocation: location, startTime: location.timestamp)
            }
        case .inProgress:
            tripPath.append(location)
            if location.speed < 0.5 {
                if stationarySince == nil { stationarySince = location.timestamp }
                if let since = stationarySince,
                   location.timestamp.timeIntervalSince(since) > tripEndStateDuration {
                    endTrip()
                }
            } else {
                stationarySince = nil
            }
        case .ended:
            tripState = .idle
            tripPath.removeAll()
        }
    }

    private func endTrip() {
        let km = currentTripDistanceKm
        // Heuristic: if average speed > 15 km/h → car, else cycling/walking
        let avgSpeed = tripPath.compactMap { $0.speed >= 0 ? $0.speed : nil }.reduce(0, +)
        let count = Double(tripPath.count)
        let avgKmH = count > 0 ? (avgSpeed / count) * 3.6 : 0
        let mode: TransportMode = avgKmH > 25 ? .car : (avgKmH > 12 ? .cycling : .walking)
        tripState = .ended(distanceKm: km, mode: mode)
        stationarySince = nil
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        authorizationStatus = status
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            startTracking()
        case .denied:
            errorMessage = LocationError.permissionDenied.errorDescription
        case .restricted:
            errorMessage = LocationError.permissionRestricted.errorDescription
        default: break
        }
    }

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        lastTriggeredZone = geofenceZones.first { $0.id.uuidString == region.identifier }
    }

    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        lastTriggeredZone = geofenceZones.first { $0.id.uuidString == region.identifier }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        errorMessage = error.localizedDescription
    }
}
