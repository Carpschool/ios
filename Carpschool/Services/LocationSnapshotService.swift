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
        continuation?.resume(throwing: error)
        continuation = nil
    }
}
