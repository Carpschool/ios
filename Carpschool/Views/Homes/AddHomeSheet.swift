import SwiftUI
import MapKit

/**
 * AddHomeSheet
 * 
 * Native sheet using Apple Maps LocationSearchService to search addresses
 * and adjust walking radius via native Slider.
 */
struct AddHomeSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onHomeAdded: (UserHome) -> Void
    
    @State private var label: String = "Home"
    @State private var searchService = LocationSearchService()
    @State private var selectedResult: LocationSearchResult?
    @State private var walkingRadius: Double = 75 // 10m to 200m
    @State private var mapPosition: MapCameraPosition = .automatic
    @State private var isSaving: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Label") {
                    TextField("Home, Dorm, Gym", text: $label)
                }
                
                Section("Search Address") {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.secondary)
                            TextField("Search street or address", text: $searchService.query)
                                .autocorrectionDisabled()
                        }
                        
                        if !searchService.completions.isEmpty {
                            List(searchService.completions) { item in
                                Button {
                                    selectCompletion(item)
                                } label: {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.title).font(.subheadline).bold()
                                        Text(item.subtitle).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .frame(height: 150)
                        }
                    }
                }
                
                if let result = selectedResult {
                    Section("Walking Radius Preview") {
                        Text(result.subtitle.isEmpty ? result.title : "\(result.title), \(result.subtitle)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        // MapKit Preview with Marker & MapCircle
                        Map(position: $mapPosition) {
                            Marker(label, coordinate: result.coordinate)
                                .tint(Color.accentColor)
                            
                            MapCircle(center: result.coordinate, radius: CLLocationDistance(walkingRadius))
                                .foregroundStyle(Color.accentColor.opacity(0.2))
                                .stroke(Color.accentColor, lineWidth: 1.5)
                        }
                        .frame(height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Walking Radius")
                                Spacer()
                                Text("\(Int(walkingRadius)) m")
                                    .bold()
                                    .foregroundStyle(Color.accentColor)
                            }
                            Slider(value: $walkingRadius, in: 10...200, step: 5)
                            HStack {
                                Text("10 m (doorstep)").font(.caption2).foregroundStyle(.secondary)
                                Spacer()
                                Text("200 m (short walk)").font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add Saved Home")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(selectedResult == nil || label.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
        }
    }
    
    private func selectCompletion(_ item: LocationSearchCompletion) {
        Task {
            if let result = try? await searchService.resolve(completion: item) {
                self.selectedResult = result
                searchService.query = ""
                searchService.completions = []
                mapPosition = .region(
                    MKCoordinateRegion(
                        center: result.coordinate,
                        latitudinalMeters: 600,
                        longitudinalMeters: 600
                    )
                )
            }
        }
    }
    
    private func save() {
        guard let result = selectedResult else { return }
        isSaving = true
        
        let addressStr = result.subtitle.isEmpty ? result.title : "\(result.title), \(result.subtitle)"
        
        Task {
            let saved = try? await NetworkService.shared.saveHome(
                label: label,
                address: addressStr,
                lat: result.coordinate.latitude,
                lng: result.coordinate.longitude,
                radius: Int(walkingRadius)
            )
            
            let finalHome = saved ?? UserHome(
                _id: UUID().uuidString,
                label: label,
                address: addressStr,
                walkingRadiusMeters: Int(walkingRadius),
                location: GeoLocation(latitude: result.coordinate.latitude, longitude: result.coordinate.longitude)
            )
            
            isSaving = false
            onHomeAdded(finalHome)
            dismiss()
        }
    }
}
