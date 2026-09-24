import Foundation
import CoreLocation
import MapKit

// MARK: - Location & Home Models

/**
 * GeoLocation
 * 
 * GeoJSON Point representation [longitude, latitude].
 */
struct GeoLocation: Codable, Hashable {
    let type: String
    let coordinates: [Double] // [longitude, latitude]
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: coordinates.count > 1 ? coordinates[1] : 0,
            longitude: coordinates.count > 0 ? coordinates[0] : 0
        )
    }
    
    init(latitude: Double, longitude: Double) {
        self.type = "Point"
        self.coordinates = [longitude, latitude]
    }
}

/**
 * UserHome
 * 
 * Saved student residence, dorm, or frequent stop with a custom walking radius.
 */
struct UserHome: Identifiable, Codable, Hashable {
    var id: String { _id ?? UUID().uuidString }
    let _id: String?
    var label: String
    var address: String
    var walkingRadiusMeters: Int // 10m to 200m
    var location: GeoLocation
    
    var coordinate: CLLocationCoordinate2D {
        location.coordinate
    }
}

/**
 * LocationSearchCompletion
 * 
 * A single search completion item from Apple MapKit MKLocalSearchCompleter.
 */
struct LocationSearchCompletion: Identifiable, Hashable {
    var id: String { "\(title)-\(subtitle)" }
    let title: String
    let subtitle: String
    let completion: MKLocalSearchCompletion
}

/**
 * LocationSearchResult
 * 
 * Resolved location with verified coordinates and map item.
 */
struct LocationSearchResult: Identifiable, Hashable {
    var id: String { "\(coordinate.latitude)-\(coordinate.longitude)" }
    let title: String
    let subtitle: String
    let coordinate: CLLocationCoordinate2D
    let mapItem: MKMapItem

    static func == (lhs: LocationSearchResult, rhs: LocationSearchResult) -> Bool {
        lhs.id == rhs.id && lhs.title == rhs.title
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(title)
    }
}
