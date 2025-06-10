import Foundation
import CoreLocation
import Combine

/// Enum to represent geofence transition types.
public enum RegionEventType {
    case entry, exit
}

/// A manager for handling location services, including permissions, fetching the user's current location, and geofencing.
@MainActor
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    // MARK: - Properties
    
    private let locationManager = CLLocationManager()
    
    @Published var location: CLLocation? = nil
    @Published var authorizationStatus: CLAuthorizationStatus
    @Published var isLoading = false
    @Published var error: Error? = nil
    
    /// Publishes region transition events (entry/exit) with the region identifier.
    public let regionEventSubject = PassthroughSubject<(regionIdentifier: String, eventType: RegionEventType), Never>()
    
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?

    /// Provides access to the set of regions currently being monitored by the CLLocationManager.
    public var monitoredRegions: Set<CLRegion> {
        return locationManager.monitoredRegions
    }

    // MARK: - Initialization
    
    override init() {
        self.authorizationStatus = locationManager.authorizationStatus
        super.init()
        locationManager.delegate = self
        // locationManager.allowsBackgroundLocationUpdates = true // Recommended for geofencing reliability
    }
    
    // MARK: - Public API: Single Location Request
    
    /// Requests the user's current location one time.
    ///
    /// This method handles requesting permission if needed and then fetches the location.
    /// - Returns: The user's current `CLLocation`.
    /// - Throws: An error if permission is denied or location cannot be determined.
    func requestLocation() async throws -> CLLocation {
        isLoading = true
        defer { isLoading = false }
        
        handleAuthorization() // Ensures correct permission level is requested
        
        return try await withCheckedThrowingContinuation { continuation in
            self.locationContinuation = continuation
            locationManager.requestLocation() // For a single location update
        }
    }
    
    // MARK: - Public API: Geofencing

    /// Starts monitoring a geofence for the given workplace details.
    /// - Parameters:
    ///   - workplaceID: A unique identifier for the workplace (e.g., from Core Data objectID).
    ///   - center: The geographical center of the region to monitor.
    ///   - radius: The radius of the region in meters.
    func startMonitoring(workplaceID: String, center: CLLocationCoordinate2D, radius: CLLocationDistance) {
        guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else {
            print("Geofencing is not available on this device.")
            // Optionally, publish an error or update UI
            return
        }

        if authorizationStatus != .authorizedAlways {
            print("Cannot start geofencing: 'Always' location authorization is required.")
            // Optionally, prompt user or guide to settings
            return
        }

        let region = CLCircularRegion(center: center, radius: radius, identifier: workplaceID)
        region.notifyOnEntry = true
        region.notifyOnExit = true
        
        // Stop monitoring any existing region with the same identifier first
        stopMonitoring(workplaceID: workplaceID)
        
        locationManager.startMonitoring(for: region)
        print("Started monitoring region: \(workplaceID)")
    }

    /// Stops monitoring a geofence for the given workplace identifier.
    /// - Parameter workplaceID: The unique identifier of the workplace region to stop monitoring.
    func stopMonitoring(workplaceID: String) {
        for region in locationManager.monitoredRegions {
            if region.identifier == workplaceID {
                locationManager.stopMonitoring(for: region)
                print("Stopped monitoring region: \(workplaceID)")
            }
        }
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latestLocation = locations.first else {
            let locationError = CLError(.locationUnknown)
            self.error = locationError
            locationContinuation?.resume(throwing: locationError)
            return
        }
        self.location = latestLocation
        locationContinuation?.resume(returning: latestLocation)
        self.error = nil
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed with error: \(error.localizedDescription)")
        self.error = error
        locationContinuation?.resume(throwing: error) // This might be problematic if geofencing also fails
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let oldStatus = self.authorizationStatus
        self.authorizationStatus = manager.authorizationStatus
        print("Location authorization status changed to: \(authorizationStatus.rawValue)")
        
        switch authorizationStatus {
        case .authorizedAlways:
            print("Location access: Always authorized.")
            // If upgrading from WhenInUse, previously started monitoring might now work
            // Or, if a request was pending, it can now proceed.
            if oldStatus == .authorizedWhenInUse {
                // Potentially re-evaluate geofences or notify user
            }
        case .authorizedWhenInUse:
            print("Location access: When in use authorized.")
            // Geofencing will be limited or not work in background.
            // Consider guiding user to settings if 'Always' is needed.
            break
        case .denied, .restricted:
            print("Location access: Denied or Restricted.")
            let authError = CLError(.denied)
            self.error = authError
            locationContinuation?.resume(throwing: authError)
            // Stop all geofencing if permission is revoked
            for region in locationManager.monitoredRegions {
                locationManager.stopMonitoring(for: region)
            }
            print("Stopped all geofence monitoring due to permission change.")
        case .notDetermined:
            print("Location access: Not determined.")
            // Still not determined, do nothing until a request is made.
            break
        @unknown default:
            break
        }
    }

    // MARK: - CLLocationManagerDelegate (Geofencing)

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        print("Entered region: \(region.identifier)")
        regionEventSubject.send((regionIdentifier: region.identifier, eventType: .entry))
    }

    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        print("Exited region: \(region.identifier)")
        regionEventSubject.send((regionIdentifier: region.identifier, eventType: .exit))
    }

    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        let regionIdentifier = region?.identifier ?? "Unknown region"
        print("Failed to monitor region \(regionIdentifier): \(error.localizedDescription)")
        // Optionally, publish this error or attempt to restart monitoring
        self.error = error // Consider if this should overwrite other errors
    }
    
    func locationManager(_ manager: CLLocationManager, didStartMonitoringFor region: CLRegion) {
        print("Successfully started monitoring for region \(region.identifier)")
    }
    
    // MARK: - Private Helpers
    
    /// Handles the authorization flow, requesting 'Always' for geofencing.
    private func handleAuthorization() {
        if authorizationStatus == .notDetermined {
            print("Requesting Always location authorization.")
            locationManager.requestAlwaysAuthorization()
        } else if authorizationStatus == .authorizedWhenInUse {
            // User has already granted 'WhenInUse'. Requesting 'Always' again might not show a prompt
            // if they previously denied 'Always' or chose 'Only While Using'.
            // For a better UX, you might guide them to app settings if 'Always' is crucial.
            print("Requesting Always location authorization (upgrade from WhenInUse).")
            locationManager.requestAlwaysAuthorization() 
        }
    }
}
