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
                            "No Saved Residences",
                            systemImage: "house.lodge",
                            description: Text("Add your dorm or apartment to view carpool routes from your area.")
                        )
                    } else {
                        ForEach(homes) { home in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(home.label)
                                        .font(.headline)
                                    Spacer()
                                    Label("\(home.walkingRadiusMeters) m radius", systemImage: "figure.walk")
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
                    Text("The walking radius circle marks how far you are comfortable walking to meet a driver.")
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
            if let primary = appState.currentUserProfile?.primaryHome {
                homes = [primary]
            } else {
                homes = [
                    UserHome(
                        _id: "home_default",
                        label: "Campus Residence",
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
