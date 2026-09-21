import SwiftUI
import MapKit

/**
 * CorridorMatchingView
 * 
 * Driver Commute Corridor Matching View using Apple MapKit.
 * Features:
 * - Direction toggle: Home → School vs. School → Home
 * - MapKit visualization of driver corridor and prospective passenger pickup points
 * - Passenger walking radius overlays (MapCircle)
 * - Candidate applications list with "Reach Out" sheet initiating negotiation
 */
struct CorridorMatchingView: View {
    @Environment(AppState.self) private var appState
    
    @State private var direction: CommuteDirection = .homeToSchool
    @State private var applications: [RiderApplication] = []
    @State private var selectedApplication: RiderApplication?
    @State private var showNegotiationSheet: Bool = false
    @State private var activeNegotiation: Negotiation?
    @State private var mapPosition: MapCameraPosition = .automatic
    @State private var isLoading: Bool = false

    // Campus Coordinates (e.g. UBC Point Grey)
    private let campusCoordinate = CLLocationCoordinate2D(latitude: 49.2606, longitude: -123.2460)

    var body: some View {
        VStack(spacing: 0) {
            // Direction Selector
            Picker("Commute Direction", selection: $direction) {
                ForEach(CommuteDirection.allCases, id: \.self) { dir in
                    Label(dir.displayName, systemImage: dir.iconName).tag(dir)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.secondarySystemBackground))
            .onChange(of: direction) { _, newDir in
                Task {
                    await searchCorridor(newDir)
                }
            }

            // Apple MapKit Corridor Map
            Map(position: $mapPosition, selection: $selectedApplication) {
                // Destination Campus Marker
                Marker(appState.currentSchool?.officialName ?? "Campus", coordinate: campusCoordinate)
                    .tint(.indigo)

                // Prospective Rider Applications
                ForEach(applications) { app in
                    if let home = app.pickupHome {
                        Marker("\(app.targetTime)", coordinate: home.coordinate)
                            .tint(.purple)
                            .tag(app)

                        MapCircle(center: home.coordinate, radius: CLLocationDistance(app.walkingRadiusMeters))
                            .foregroundStyle(Color.purple.opacity(0.18))
                            .stroke(Color.purple, lineWidth: 1.5)
                    }
                }
            }
            .mapControls {
                MapUserLocationButton()
                MapCompass()
                MapScaleView()
            }
            .frame(height: 300)

            // Rider Applications Along Corridor
            List {
                Section {
                    if applications.isEmpty && !isLoading {
                        ContentUnavailableView(
                            "No Matching Riders",
                            systemImage: "figure.walk.motion",
                            description: Text("No student commute applications found along this corridor right now.")
                        )
                    } else {
                        ForEach(applications) { app in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "figure.wave")
                                        .foregroundStyle(.purple)
                                        .font(.title3)

                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack {
                                            Text(app.pickupHome?.label ?? "Campus Corridor")
                                                .font(.headline)
                                            Spacer()
                                            Text(app.targetTime)
                                                .font(.subheadline.bold())
                                                .foregroundStyle(Color.accentColor)
                                        }

                                        Text(app.pickupHome?.address ?? "Pickup location")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                if let notes = app.notes, !notes.isEmpty {
                                    Text("\"\(notes)\"")
                                        .font(.caption)
                                        .italic()
                                        .foregroundStyle(.secondary)
                                }

                                HStack {
                                    Label("\(app.walkingRadiusMeters)m walking radius", systemImage: "figure.walk")
                                        .font(.caption2)
                                        .foregroundStyle(.purple)

                                    Spacer()

                                    Button {
                                        reachOut(to: app)
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: "bubble.left.and.bubble.right.fill")
                                            Text("Reach Out")
                                        }
                                        .font(.caption.bold())
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.small)
                                    .tint(Color.accentColor)
                                }
                            }
                            .padding(.vertical, 4)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedApplication = app
                                if let coord = app.pickupHome?.coordinate {
                                    withAnimation {
                                        mapPosition = .region(
                                            MKCoordinateRegion(
                                                center: coord,
                                                latitudinalMeters: 1000,
                                                longitudinalMeters: 1000
                                            )
                                        )
                                    }
                                }
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text("Prospective Passengers Along Route")
                        Spacer()
                        if isLoading { ProgressView() }
                    }
                } footer: {
                    Text("Reach out to suggest pickup locations within the rider's walking radius. Zero payments, pure reciprocal student carpools.")
                }
            }
            .listStyle(.insetGrouped)
        }
        .navigationTitle("Corridor Matching")
        .sheet(item: $activeNegotiation) { neg in
            NavigationStack {
                NegotiationChatView(negotiation: neg)
            }
        }
        .task {
            await searchCorridor(direction)
        }
    }

    private func searchCorridor(_ dir: CommuteDirection) async {
        isLoading = true
        applications = (try? await NetworkService.shared.searchCorridor(direction: dir)) ?? []
        
        // Adjust map to show campus and first application
        if let first = applications.first?.pickupHome?.coordinate {
            let midLat = (first.latitude + campusCoordinate.latitude) / 2
            let midLng = (first.longitude + campusCoordinate.longitude) / 2
            mapPosition = .region(
                MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: midLat, longitude: midLng),
                    latitudinalMeters: 6000,
                    longitudinalMeters: 6000
                )
            )
        } else {
            mapPosition = .region(
                MKCoordinateRegion(
                    center: campusCoordinate,
                    latitudinalMeters: 4000,
                    longitudinalMeters: 4000
                )
            )
        }
        isLoading = false
    }

    private func reachOut(to app: RiderApplication) {
        let neg = Negotiation(
            _id: "neg_\(UUID().uuidString.prefix(8))",
            applicationId: app._id,
            driverId: "driver_me",
            riderId: app.riderId ?? "rider_student",
            direction: app.direction,
            status: "OPEN",
            targetDate: ISO8601DateFormatter().string(from: Date()),
            proposals: [
                Proposal(
                    proposalId: "prop_1",
                    pickupPointName: app.pickupHome?.address ?? "Agreed Corner",
                    pickupCoordinates: app.pickupHome?.location.coordinates ?? [-123.1856, 49.2642],
                    proposedTime: app.targetTime,
                    status: .pending,
                    proposedBy: "driver"
                )
            ],
            messages: [
                ChatMessage(
                    _id: "msg_1",
                    senderId: "driver_me",
                    senderName: "Me (Driver)",
                    message: "Hi! I see your application for \(app.targetTime). I'm driving this route and have an empty seat.",
                    timestamp: "Just now",
                    isSystem: false
                )
            ]
        )
        self.activeNegotiation = neg
    }
}
