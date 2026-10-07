import SwiftUI
import MapKit

struct NewCommuteView: View {
    enum Kind { case request, drive }
    let kind: Kind

    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss
    @State private var homes: [Home]?
    @State private var homeId = ""
    @State private var direction: Direction = .toSchool
    @State private var weekly = true
    @State private var days: Set<Int> = [1, 2, 3, 4, 5]
    @State private var date = Date.now
    @State private var start = Self.time(7, 30)
    @State private var end = Self.time(8, 0)
    @State private var seats = 3
    @State private var route: MKRoute?
    @State private var routeError: String?
    @State private var busy = false
    @State private var error: String?

    static func time(_ h: Int, _ m: Int) -> Date { Calendar.current.date(bySettingHour: h, minute: m, second: 0, of: .now) ?? .now }

    private var home: Home? { homes?.first { $0.id == homeId } }
    private var valid: Bool {
        home != nil && (weekly ? !days.isEmpty : true) && Fmt.hm.string(from: start) <= Fmt.hm.string(from: end) && (kind == .request || route != nil)
    }

    var body: some View {
        Form {
            if let homes, homes.isEmpty {
                ContentUnavailableView("Add a home first", systemImage: "house", description: Text("Commutes start or end at one of your homes."))
            }
            Section("Trip") {
                Picker("Home", selection: $homeId) {
                    ForEach(homes ?? []) { Text($0.label).tag($0.id) }
                }
                Picker("Direction", selection: $direction) {
                    ForEach(Direction.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
            }
            Section("When") {
                Picker("Repeat", selection: $weekly) {
                    Text("Weekly").tag(true)
                    Text("One day").tag(false)
                }
                .pickerStyle(.segmented)
                if weekly {
                    DayPicker(days: $days)
                } else {
                    DatePicker("Date", selection: $date, in: Calendar.current.startOfDay(for: .now)..., displayedComponents: .date)
                }
                DatePicker(direction == .toSchool ? "Arrive after" : "Leave after", selection: $start, displayedComponents: .hourAndMinute)
                DatePicker(direction == .toSchool ? "Arrive by" : "Leave by", selection: $end, displayedComponents: .hourAndMinute)
            }
            if kind == .drive {
                Section {
                    Stepper("Seats to offer: \(seats)", value: $seats, in: 1...max(1, min(model.meta?.limits.seats ?? 4, 4)))
                }
                Section {
                    routeMap
                        .frame(height: 240)
                        .listRowInsets(EdgeInsets())
                    if let route {
                        LabeledContent("Route", value: "\(Fmt.distance(route.distance)) · about \(Int(route.expectedTravelTime / 60)) min")
                    } else if let routeError {
                        Label(routeError, systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
                    }
                } header: { Text("Your route") } footer: { Text("We match riders who live a short walk from this route.") }
            }
            if let error { Section { Label(error, systemImage: "exclamationmark.circle").foregroundStyle(.red) } }
        }
        .navigationTitle(kind == .drive ? "Post a Drive" : "Request a Ride")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                if busy { ProgressView() } else {
                    Button(kind == .drive ? "Post" : "Request") { Task { await submit() } }.disabled(!valid)
                }
            }
        }
        .onChange(of: direction) { _, d in
            if d == .home && Fmt.hm.string(from: start) < "12:00" { start = Self.time(15, 0); end = Self.time(15, 30) }
            if d == .toSchool && Fmt.hm.string(from: start) >= "12:00" { start = Self.time(7, 30); end = Self.time(8, 0) }
        }
        .task {
            homes = try? await model.get([Home].self, "/homes")
            if homeId.isEmpty { homeId = homes?.first?.id ?? "" }
        }
        .task(id: "\(homeId)\(direction.rawValue)") { if kind == .drive { await loadRoute() } }
    }

    @ViewBuilder private var routeMap: some View {
        if let route {
            Map(initialPosition: .rect(route.polyline.boundingMapRect.insetBy(dx: -600, dy: -600))) {
                MapPolyline(route.polyline).stroke(Color.brand, lineWidth: 5)
                if let h = home { Marker(h.label, systemImage: "house.fill", coordinate: h.location.coordinate).tint(.brand) }
                if let c = model.meta?.campusPoint.coordinate { Marker("School", systemImage: "building.columns.fill", coordinate: c).tint(.highlight) }
            }
            .id(route.distance)
        } else {
            ZStack { Color(.tertiarySystemFill); if routeError == nil && home != nil { ProgressView() } }
        }
    }

    private func loadRoute() async {
        route = nil; routeError = nil
        guard let h = home, let campus = model.meta?.campusPoint.coordinate else { return }
        let a = MKMapItem(placemark: MKPlacemark(coordinate: h.location.coordinate))
        let b = MKMapItem(placemark: MKPlacemark(coordinate: campus))
        let req = MKDirections.Request()
        req.source = direction == .toSchool ? a : b
        req.destination = direction == .toSchool ? b : a
        req.transportType = .automobile
        do { route = try await MKDirections(request: req).calculate().routes.first }
        catch { routeError = "Couldn't find a driving route." }
    }

    private func submit() async {
        guard let h = home else { return }
        busy = true; error = nil
        defer { busy = false }
        var commute: [String: Any] = [
            "homeId": h.id, "direction": direction.rawValue,
            "startTime": Fmt.hm.string(from: start), "endTime": Fmt.hm.string(from: end),
            "dates": weekly ? [] : [Fmt.isoDay.string(from: date)],
            "days": weekly ? days.sorted() : [],
        ]
        do {
            if kind == .drive, let route {
                let coords = Self.coordinates(route.polyline, max: 400).map { [$0.longitude, $0.latitude].map { ($0 * 1e6).rounded() / 1e6 } }
                let d = try await model.get(IdOnly.self, "/drives", body: ["commute": commute, "route": coords, "seats": seats])
                model.revision += 1
                router.home.removeLast()
                router.home.append(Route.drive(d.id))
            } else {
                commute["homeId"] = h.id
                try await model.send("/requests", body: commute)
                model.revision += 1
                dismiss()
            }
        } catch { self.error = error.localizedDescription }
    }

    /// Polyline points, evenly thinned to stay under the server limit.
    static func coordinates(_ line: MKPolyline, max: Int) -> [CLLocationCoordinate2D] {
        var all = [CLLocationCoordinate2D](repeating: .init(), count: line.pointCount)
        line.getCoordinates(&all, range: NSRange(location: 0, length: line.pointCount))
        guard all.count > max else { return all }
        let step = Double(all.count - 1) / Double(max - 1)
        return (0..<max).map { all[Int((Double($0) * step).rounded())] }
    }
}

struct DayPicker: View {
    @Binding var days: Set<Int>
    var body: some View {
        HStack(spacing: 6) {
            ForEach([1, 2, 3, 4, 5, 6, 0], id: \.self) { d in
                let on = days.contains(d)
                Button {
                    if on { days.remove(d) } else { days.insert(d) }
                } label: {
                    Text(Fmt.dayNames[d].prefix(1))
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .foregroundStyle(on ? Color.white : Color.primary)
                        .background(on ? Color.brand : Color(.tertiarySystemFill), in: .circle)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Calendar.current.weekdaySymbols[d])
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .sensoryFeedback(.selection, trigger: days)
        .padding(.vertical, 4)
    }
}
