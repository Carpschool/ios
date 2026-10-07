import CoreLocation

/// Single, discrete location reads for boarding and drop-off. No tracking.
@MainActor
enum LocationSnapshot {
    private static let manager = CLLocationManager()

    static func here(fallback: GeoPoint) async -> (point: GeoPoint, approximate: Bool) {
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
            for _ in 0..<40 where manager.authorizationStatus == .notDetermined {
                try? await Task.sleep(for: .milliseconds(250))
            }
        }
        guard [.authorizedWhenInUse, .authorizedAlways].contains(manager.authorizationStatus) else { return (fallback, true) }
        let point = await withTaskGroup(of: GeoPoint?.self) { group -> GeoPoint? in
            group.addTask {
                do {
                    for try await update in CLLocationUpdate.liveUpdates() {
                        if let loc = update.location, loc.horizontalAccuracy < 200 { return GeoPoint(loc.coordinate) }
                    }
                } catch {}
                return nil
            }
            group.addTask {
                try? await Task.sleep(for: .seconds(8))
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
        return point.map { ($0, false) } ?? (fallback, true)
    }
}
