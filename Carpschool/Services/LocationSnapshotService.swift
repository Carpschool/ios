import Foundation
import CoreLocation

/**
 * LocationSnapshotService
 * 
 * Captures discrete, single-read GPS location snapshots at two specific moments:
 * 1. Passenger Boarding (verifies passenger boarding spot).
 * 2. End Ride (verifies arrival at school).
 * 
 * ZERO continuous background GPS streaming is performed.
 */
class LocationSnapshotService: NSObject, CLLocationManagerDelegate {
    static let shared = LocationSnapshotService()
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocationCoordinate2D, Error>?

    override private init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
    }

    func requestAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    /**
     * Captures a single discrete GPS coordinate read and immediately stops location updates.
     */
    func captureDiscreteSnapshot() async throws -> CLLocationCoordinate2D {
        #if targetEnvironment(simulator)
        // In simulator environments, return realistic campus coordinate if location is simulated or unavailable
        if manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted {
            return CLLocationCoordinate2D(latitude: 49.2606, longitude: -123.2460)
        }
        #endif
        
        requestAuthorization()
        
        return try await withCheckedThrowingContinuation { cont in
            self.continuation = cont
            self.manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.first {
            continuation?.resume(returning: location.coordinate)
            continuation = nil
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        #if targetEnvironment(simulator)
        // Graceful fallback for simulator when no GPS hardware is simulated
        continuation?.resume(returning: CLLocationCoordinate2D(latitude: 49.2606, longitude: -123.2460))
        continuation = nil
        #else
        continuation?.resume(throwing: error)
        continuation = nil
        #endif
    }
}
