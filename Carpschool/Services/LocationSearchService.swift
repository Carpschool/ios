import Foundation
import MapKit
import Observation

/**
 * LocationSearchService
 * 
 * Native Apple MapKit local search & autocomplete service.
 * Leverages MKLocalSearchCompleter for fast, zero-cost, on-device address search.
 */
@MainActor
@Observable
class LocationSearchService: NSObject, MKLocalSearchCompleterDelegate {
    var query: String = "" {
        didSet {
            completer.queryFragment = query
        }
    }
    
    var completions: [LocationSearchCompletion] = []
    var isSearching: Bool = false
    
    private let completer: MKLocalSearchCompleter
    
    override init() {
        self.completer = MKLocalSearchCompleter()
        super.init()
        self.completer.delegate = self
        self.completer.resultTypes = [.address, .pointOfInterest]
    }
    
    // MARK: - Completer Delegate
    
    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let results = completer.results.map {
            LocationSearchCompletion(title: $0.title, subtitle: $0.subtitle, completion: $0)
        }
        Task { @MainActor in
            self.completions = results
            self.isSearching = false
        }
    }
    
    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in
            self.isSearching = false
        }
    }
    
    // MARK: - Coordinate Resolution
    
    func resolve(completion: LocationSearchCompletion) async throws -> LocationSearchResult {
        let request = MKLocalSearch.Request(completion: completion.completion)
        let search = MKLocalSearch(request: request)
        let response = try await search.start()
        
        guard let mapItem = response.mapItems.first else {
            throw NSError(domain: "LocationSearch", code: 404, userInfo: [NSLocalizedDescriptionKey: "No coordinates found for selected address."])
        }
        
        return LocationSearchResult(
            title: completion.title,
            subtitle: completion.subtitle,
            coordinate: mapItem.placemark.coordinate,
            mapItem: mapItem
        )
    }
    
    func searchDirect(query: String) async throws -> [LocationSearchResult] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = [.address, .pointOfInterest]
        
        let search = MKLocalSearch(request: request)
        let response = try await search.start()
        
        return response.mapItems.map { item in
            LocationSearchResult(
                title: item.name ?? "Unknown Location",
                subtitle: item.placemark.title ?? "",
                coordinate: item.placemark.coordinate,
                mapItem: item
            )
        }
    }
}
