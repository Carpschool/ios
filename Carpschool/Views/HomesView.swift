import SwiftUI
import MapKit

/**
 * HomesView
 * 
 * Native Apple MapKit visualizer for Saved Student Residences.
 * Features:
 * - Interactive Apple Map with Marker annotations and MapCircle walking radius overlays (10m - 200m)
 * - Map controls: MapUserLocationButton, MapCompass, MapScaleView
 * - InsetGrouped list of saved locations
 * - Native Apple Maps address search sheet via LocationSearchService
 */
struct HomesView: View {
    @Environment(AppState.self) private var appState
    
    @State private var homes: [UserHome] = []
    @State private var selectedHome: UserHome?
    @State private var showAddSheet: Bool = false
    @State private var mapPosition: MapCameraPosition = .automatic
    @State private var isLoading: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Interactive Apple Map
            Map(position: $mapPosition, selection: $selectedHome) {
                ForEach(homes) { home in
                    Marker(home.label, coordinate: home.coordinate)
                        .tint(Color.accentColor)
                        .tag(home)
                    
                    MapCircle(center: home.coordinate, radius: CLLocationDistance(home.walkingRadiusMeters))
                        .foregroundStyle(Color.accentColor.opacity(0.18))
                        .stroke(Color.accentColor, lineWidth: 1.5)
                }
            }
            .mapControls {
                MapUserLocationButton()
                MapCompass()
                MapScaleView()
            }
            .frame(height: 280)
            
            // Saved Homes List
            List {
                Section {
                    if homes.isEmpty && !isLoading {
                        ContentUnavailableView(
                            "No Saved Locations",
                            systemImage: "house.lodge",
                            description: Text("Add your residence, dorm, or frequent pickup spots to easily match with carpools.")
                        )
                    } else {
                        ForEach(homes) { home in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(home.label)
                                        .font(.headline)
                                    Spacer()
                                    Label("\(home.walkingRadiusMeters)m radius", systemImage: "figure.walk")
                                        .font(.caption.bold())
                                        .foregroundStyle(Color.accentColor)
                                }
                                Text(home.address)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedHome = home
                                withAnimation {
                                    mapPosition = .region(
                                        MKCoordinateRegion(
                                            center: home.coordinate,
                                            latitudinalMeters: 600,
                                            longitudinalMeters: 600
                                        )
                                    )
                                }
                            }
                        }
                        .onDelete(perform: deleteHome)
                    }
                } header: {
                    HStack {
                        Text("Saved Residences")
                        Spacer()
                        if isLoading {
                            ProgressView()
                        }
                    }
                } footer: {
                    Text("The walking radius circle indicates how far you are comfortable walking to meet a driver.")
                }
            }
            .listStyle(.insetGrouped)
        }
        .navigationTitle("Saved Homes")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddSheet = true
                } label: {
                    Label("Add Home", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddHomeSheet(onHomeAdded: { newHome in
                homes.append(newHome)
                selectedHome = newHome
                mapPosition = .region(
                    MKCoordinateRegion(
                        center: newHome.coordinate,
                        latitudinalMeters: 800,
                        longitudinalMeters: 800
                    )
                )
            })
        }
        .task {
            await loadHomes()
        }
    }
    
    private func loadHomes() async {
        isLoading = true
        let fetched = (try? await NetworkService.shared.fetchHomes()) ?? []
        if fetched.isEmpty {
            // Seed with primary home from state or realistic student home
            if let primary = appState.currentUserProfile?.primaryHome {
                homes = [primary]
            } else {
                homes = [
                    UserHome(
                        _id: "home_default",
                        label: "Point Grey Residence",
                        address: "2329 West Mall, Vancouver, BC",
                        walkingRadiusMeters: 75,
                        location: GeoLocation(latitude: 49.2606, longitude: -123.2460)
                    )
                ]
            }
        } else {
            homes = fetched
        }
        
        if let first = homes.first {
            mapPosition = .region(
                MKCoordinateRegion(
                    center: first.coordinate,
                    latitudinalMeters: 1200,
                    longitudinalMeters: 1200
                )
            )
        }
        isLoading = false
    }
    
    private func deleteHome(at offsets: IndexSet) {
        for index in offsets {
            let home = homes[index]
            if let id = home._id {
                Task {
                    _ = try? await NetworkService.shared.deleteHome(id: id)
                }
            }
        }
        homes.remove(atOffsets: offsets)
    }
}

/**
 * AddHomeSheet
 * 
 * Native sheet utilizing Apple Maps LocationSearchService to search addresses
 * and adjust walking radius via native Slider.
 */
struct AddHomeSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onHomeAdded: (UserHome) -> Void
    
    @State private var label: String = "My Dorm"
    @State private var searchService = LocationSearchService()
    @State private var selectedResult: LocationSearchResult?
    @State private var walkingRadius: Double = 75 // 10m to 200m
    @State private var mapPosition: MapCameraPosition = .automatic
    @State private var isSaving: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Location Details") {
                    TextField("Label (e.g. Home, Dorm, Gym)", text: $label)
                }
                
                Section("Search Address (Apple Maps)") {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.secondary)
                            TextField("Type address or street name...", text: $searchService.query)
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
                    Section("Coordinate & Walking Radius Preview") {
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
                                Text("\(Int(walkingRadius)) meters")
                                    .bold()
                                    .foregroundStyle(Color.accentColor)
                            }
                            Slider(value: $walkingRadius, in: 10...200, step: 5)
                            HStack {
                                Text("10m (doorstep)").font(.caption2).foregroundStyle(.secondary)
                                Spacer()
                                Text("200m (short walk)").font(.caption2).foregroundStyle(.secondary)
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
