import SwiftUI
import MapKit

struct DriveDetailView: View {
    let id: String
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @State private var drive: Drive?
    @State private var matches: [Match]?
    @State private var error: String?
    @State private var busy: String?
    @State private var confirmCancel = false
    @State private var toast: Toast?

    var body: some View {
        Group {
            if let drive {
                List {
                    Section {
                        corridorMap(drive)
                            .frame(height: 260)
                            .listRowInsets(EdgeInsets())
                        LabeledContent("Schedule", value: drive.schedule)
                        LabeledContent("Time", value: drive.window)
                        LabeledContent("Seats open", value: "\(drive.availableSeats) of \(drive.seats)")
                    }
                    if !drive.activeRiders.isEmpty {
                        Section {
                            NavigationLink(value: Route.ride(drive.id)) {
                                Label("\(drive.activeRiders.count) rider\(drive.activeRiders.count == 1 ? "" : "s") locked in", systemImage: "ticket.fill")
                            }
                        }
                    }
                    Section {
                        if let matches {
                            if matches.isEmpty {
                                ContentUnavailableView(drive.availableSeats < 1 ? "Your car is full" : "No riders yet",
                                                       systemImage: "person.crop.circle.badge.questionmark",
                                                       description: Text(drive.availableSeats < 1 ? "All seats are taken for this drive." : "We check again every 30 seconds."))
                            }
                            ForEach(matches) { m in
                                HStack(spacing: 12) {
                                    InitialsAvatar(id: m.rider)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Rider \(Fmt.shortId(m.rider))").font(.headline)
                                        Label("\(Int(m.distanceMeters)) m from route · \(Fmt.clock(m.startTime))–\(Fmt.clock(m.endTime))", systemImage: "figure.walk")
                                            .font(.subheadline).foregroundStyle(.secondary)
                                            .labelStyle(.titleAndIcon)
                                    }
                                    Spacer()
                                    Button {
                                        Task { await reach(m) }
                                    } label: {
                                        if busy == m.requestId { ProgressView() } else { Text("Reach Out") }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .buttonBorderShape(.capsule)
                                    .controlSize(.small)
                                    .disabled(busy != nil)
                                }
                                .padding(.vertical, 4)
                            }
                        } else {
                            ProgressView().frame(maxWidth: .infinity)
                        }
                    } header: { Text("Riders along your route") } footer: {
                        Text("Sorted by distance from your route. Everyone is within their own walking distance.")
                    }
                    if drive.status == "active" {
                        Section {
                            Button("Cancel Drive", role: .destructive) { confirmCancel = true }
                        }
                    }
                }
            } else if let error {
                ErrorBanner(message: error) { Task { await load() } }
            } else {
                ProgressView()
            }
        }
        .navigationTitle(drive?.direction.label ?? "Drive")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                matches = (try? await model.get([Match].self, "/drives/\(id)/matches")) ?? matches
            }
        }
        .refreshable { await load() }
        .confirmationDialog("Cancel this drive?", isPresented: $confirmCancel, titleVisibility: .visible) {
            Button("Cancel Drive", role: .destructive) { Task { await cancel() } }
        } message: { Text("Riders who haven't boarded get an email and their requests reopen.") }
        .toast($toast)
    }

    private func corridorMap(_ d: Drive) -> some View {
        let line = d.routeCoordinates
        return Map(initialPosition: .automatic) {
            if line.count > 1 {
                MapPolyline(coordinates: line).stroke(Color.brand, lineWidth: 5)
                Marker("Start", systemImage: "flag.fill", coordinate: line[0]).tint(.green)
                Marker("End", systemImage: "flag.checkered", coordinate: line[line.count - 1]).tint(.red)
            }
            ForEach(d.activeRiders) { p in
                Marker("Pickup \(Fmt.clock(p.time))", systemImage: "figure.wave", coordinate: p.pickup.coordinate).tint(.highlight)
            }
        }
        .safeAreaPadding(8)
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .accessibilityLabel("Corridor map")
    }

    private func load() async {
        do {
            async let m = model.get([Match].self, "/drives/\(id)/matches")
            drive = try await model.get(Drive.self, "/drives/" + id)
            matches = try await m
            error = nil
        } catch { if drive == nil { self.error = error.localizedDescription } }
    }

    private func reach(_ m: Match) async {
        busy = m.requestId
        defer { busy = nil }
        do {
            let n = try await model.get(IdOnly.self, "/drives/\(id)/negotiations", body: ["requestId": m.requestId])
            router.open(.chat(n.id))
        } catch { toast = Toast(text: error.localizedDescription, isError: true) }
    }

    private func cancel() async {
        do {
            try await model.send("/drives/" + id, method: "DELETE")
            model.revision += 1
            router.home = NavigationPath()
        } catch { toast = Toast(text: error.localizedDescription, isError: true) }
    }
}
