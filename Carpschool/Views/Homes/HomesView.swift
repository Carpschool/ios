import SwiftUI
import MapKit

struct HomesView: View {
    @Environment(AppModel.self) private var model
    @State private var homes: [Home]?
    @State private var error: String?
    @State private var editing: HomeEditorView.Target?
    @State private var toast: Toast?

    var body: some View {
        List {
            if let homes {
                if homes.isEmpty {
                    ContentUnavailableView {
                        Label("No homes yet", systemImage: "house")
                    } description: {
                        Text("Pickups are matched to where you live. Your exact address is never shown to other students.")
                    } actions: {
                        Button("Add Home") { editing = .new }.buttonStyle(.borderedProminent)
                    }
                    .listRowBackground(Color.clear)
                }
                ForEach(homes) { h in
                    Button { editing = .edit(h) } label: {
                        HStack(spacing: 14) {
                            Map(initialPosition: .region(.init(center: h.location.coordinate, latitudinalMeters: max(h.walkingRadius * 4, 300), longitudinalMeters: max(h.walkingRadius * 4, 300))), interactionModes: []) {
                                MapCircle(center: h.location.coordinate, radius: h.walkingRadius).foregroundStyle(Color.brand.opacity(0.2)).stroke(Color.brand, lineWidth: 1)
                                Annotation("", coordinate: h.location.coordinate) { Circle().fill(Color.brand).frame(width: 10, height: 10) }
                            }
                            .frame(width: 64, height: 64)
                            .clipShape(.rect(cornerRadius: 12))
                            .allowsHitTesting(false)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(h.label).font(.headline).foregroundStyle(.primary)
                                Label("Walk up to \(Int(h.walkingRadius)) m", systemImage: "figure.walk")
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .swipeActions {
                        Button("Delete", role: .destructive) { Task { await delete(h) } }
                    }
                }
            } else if let error {
                ErrorBanner(message: error) { Task { await load() } }
            } else {
                ProgressView().frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Homes")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let homes, homes.count < (model.meta?.limits.homes ?? 3) {
                Button("Add Home", systemImage: "plus") { editing = .new }
            }
        }
        .sheet(item: $editing) { t in
            HomeEditorView(target: t) { msg in
                toast = Toast(text: msg)
                Task { await load() }
            }
        }
        .task { await load() }
        .refreshable { await load() }
        .toast($toast)
    }

    private func load() async {
        do { homes = try await model.get([Home].self, "/homes"); error = nil }
        catch { self.error = error.localizedDescription }
    }

    private func delete(_ h: Home) async {
        do { try await model.send("/homes/" + h.id, method: "DELETE"); toast = Toast(text: "Home removed"); await load() }
        catch { toast = Toast(text: error.localizedDescription, isError: true) }
    }
}

struct HomeEditorView: View {
    enum Target: Identifiable { case new, edit(Home)
        var id: String { if case .edit(let h) = self { return h.id }; return "new" }
    }
    let target: Target
    var onSaved: (String) -> Void

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var label = "Home"
    @State private var radius: Double = 100
    @State private var center: CLLocationCoordinate2D?
    @State private var camera: MapCameraPosition = .automatic
    @State private var query = ""
    @State private var results: [MKMapItem] = []
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ZStack {
                    Map(position: $camera) {
                        if let center {
                            MapCircle(center: center, radius: radius)
                                .foregroundStyle(Color.brand.opacity(0.18))
                                .stroke(Color.brand, lineWidth: 1.5)
                        }
                        UserAnnotation()
                    }
                    .mapControls { MapUserLocationButton(); MapCompass() }
                    .onMapCameraChange(frequency: .continuous) { ctx in center = ctx.region.center }
                    Image(systemName: "mappin")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(.brand)
                        .offset(y: -17)
                        .shadow(radius: 2)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
                .overlay(alignment: .top) {
                    if !results.isEmpty {
                        List(results, id: \.self) { item in
                            Button {
                                pick(item)
                            } label: {
                                VStack(alignment: .leading) {
                                    Text(item.name ?? "Place").foregroundStyle(.primary)
                                    Text(item.placemark.title ?? "").font(.footnote).foregroundStyle(.secondary).lineLimit(1)
                                }
                            }
                        }
                        .listStyle(.plain)
                        .frame(maxHeight: 280)
                        .clipShape(.rect(cornerRadius: 14))
                        .padding()
                        .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
                    }
                }

                Form {
                    Section {
                        TextField("Label", text: $label)
                        VStack(alignment: .leading) {
                            LabeledContent("Walking distance", value: "\(Int(radius)) m")
                            Slider(value: $radius, in: 10...200, step: 5) { Text("Walking distance") }
                        }
                    } footer: {
                        Text("Move the map to put the pin on your home. Drivers only see a pickup spot you both agree on.")
                    }
                    if let error { Label(error, systemImage: "exclamationmark.circle").foregroundStyle(.red) }
                }
                .frame(height: 260)
                .scrollDisabled(true)
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search address")
            .task(id: query) { await search() }
            .navigationTitle(isEdit ? "Edit Home" : "Add Home")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    if busy { ProgressView() } else { Button("Save") { Task { await save() } }.disabled(center == nil || label.isEmpty) }
                }
            }
            .onAppear(perform: setup)
        }
    }

    private var isEdit: Bool { if case .edit = target { return true }; return false }

    private func setup() {
        if case .edit(let h) = target {
            label = h.label; radius = h.walkingRadius
            camera = .region(.init(center: h.location.coordinate, latitudinalMeters: 600, longitudinalMeters: 600))
        } else if let c = model.meta?.campusPoint.coordinate {
            camera = .region(.init(center: c, latitudinalMeters: 4000, longitudinalMeters: 4000))
        } else {
            camera = .userLocation(fallback: .automatic)
        }
    }

    private func search() async {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard q.count >= 3 else { results = []; return }
        try? await Task.sleep(for: .milliseconds(300))
        guard !Task.isCancelled else { return }
        let req = MKLocalSearch.Request()
        req.naturalLanguageQuery = q
        req.resultTypes = [.address, .pointOfInterest]
        if let c = model.meta?.campusPoint.coordinate { req.region = .init(center: c, latitudinalMeters: 40000, longitudinalMeters: 40000) }
        results = (try? await MKLocalSearch(request: req).start().mapItems) ?? []
    }

    private func pick(_ item: MKMapItem) {
        withAnimation { camera = .region(.init(center: item.placemark.coordinate, latitudinalMeters: 500, longitudinalMeters: 500)) }
        query = ""
        results = []
    }

    private func save() async {
        guard let center else { return }
        busy = true; error = nil
        defer { busy = false }
        let body: [String: Any] = ["label": label.trimmingCharacters(in: .whitespaces), "location": GeoPoint(center).json, "walkingRadius": radius]
        do {
            if case .edit(let h) = target { try await model.send("/homes/" + h.id, method: "PUT", body: body) }
            else { try await model.send("/homes", body: body) }
            onSaved(isEdit ? "Home updated" : "Home added")
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}
