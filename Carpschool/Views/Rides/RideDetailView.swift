import SwiftUI
import MapKit

struct RideDetailView: View {
    let id: String
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @State private var drive: Drive?
    @State private var error: String?
    @State private var pin: String?
    @State private var pinBusy = false
    @State private var boarding: Passenger?
    @State private var dropping: Passenger?
    @State private var leaving: Passenger?
    @State private var toast: Toast?

    private var driver: Bool { model.isDriver }

    var body: some View {
        Group {
            if let d = drive {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(d.schedule).font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
                            Text(d.direction.label).font(.largeTitle.bold())
                            if driver { Text("\(d.activeRiders.count) rider(s) · \(d.availableSeats) seat(s) open").foregroundStyle(.secondary) }
                        }
                        if d.status != "active" { StatusBadge(text: d.status.capitalized) }
                        if driver { driverView(d) } else { riderView(d) }
                    }
                    .padding(20)
                }
                .background(Color(.systemGroupedBackground))
            } else if let error {
                ErrorBanner(message: error) { Task { await load() } }
            } else {
                ProgressView()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let d = drive, !driver {
                ToolbarItem(placement: .topBarTrailing) { SafetyMenu(subject: d.owner, who: "driver \(Fmt.shortId(d.owner))") }
            }
        }
        .task { await load() }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(20))
                await load()
            }
        }
        .refreshable { await load() }
        .sheet(item: $boarding) { p in
            BoardSheet(rideId: id, passenger: p) { msg in toast = Toast(text: msg); Task { await load() } }
        }
        .confirmationDialog("Complete drop-off?", isPresented: .init(get: { dropping != nil }, set: { if !$0 { dropping = nil } }), titleVisibility: .visible) {
            Button("Complete") { let p = dropping; Task { await dropoff(p) } }
        } message: { Text("We'll save one location snapshot and mark the ride done.") }
        .confirmationDialog(driver ? "Remove this rider?" : "Leave this carpool?", isPresented: .init(get: { leaving != nil }, set: { if !$0 { leaving = nil } }), titleVisibility: .visible) {
            Button(driver ? "Remove Rider" : "Leave Carpool", role: .destructive) { let p = leaving; Task { await leave(p) } }
        } message: {
            Text(driver ? "Their seat opens up and they get an email." : "Your seat is released and the driver gets an email. Your request goes back into the pool.")
        }
        .toast($toast)
    }

    // MARK: Rider boarding pass

    @ViewBuilder private func riderView(_ d: Drive) -> some View {
        ForEach(d.passengers) { p in
            VStack(spacing: 0) {
                PinMap(coordinate: p.pickup.coordinate, height: 200)
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("PICKUP").font(.caption.weight(.semibold)).tracking(1.5).opacity(0.7)
                            Text(Fmt.clock(p.time)).font(.system(size: 40, weight: .bold, design: .rounded).monospacedDigit())
                        }
                        Spacer()
                        StatusBadge(text: statusLabel(p.status), color: p.status == "boarded" ? .green : .highlight)
                    }
                    Rectangle().fill(.clear).frame(height: 1)
                        .overlay(Rectangle().stroke(style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])).foregroundStyle(.white.opacity(0.3)))
                    if p.status == "locked" && d.status == "active" {
                        if let pin {
                            VStack(spacing: 4) {
                                Text("BOARDING PIN").font(.caption.weight(.semibold)).tracking(1.5).opacity(0.7)
                                Text(pin).accessibilityIdentifier("boardingPIN")
                                    .font(.system(size: 56, weight: .heavy, design: .monospaced))
                                    .tracking(14)
                                    .foregroundStyle(.highlight)
                                    .contentTransition(.numericText())
                                    .accessibilityLabel("PIN " + pin.map(String.init).joined(separator: " "))
                                Text("Show this to your driver. A new PIN replaces the old one.")
                                    .font(.footnote).opacity(0.75).multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                        } else {
                            Button { Task { await getPin() } } label: {
                                HStack { Spacer(); if pinBusy { ProgressView().tint(.black) } else { Text("Show Boarding PIN").bold() }; Spacer() }
                                    .padding(.vertical, 6)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.highlight)
                            .foregroundStyle(.black)
                            .controlSize(.large)
                        }
                    } else {
                        Text(p.status == "boarded" ? "You're on board. Have a good ride." : "This ride is finished.").opacity(0.85)
                    }
                }
                .padding(20)
                .foregroundStyle(.white)
            }
            .background(Color.brand)
            .clipShape(.rect(cornerRadius: 26))
            .shadow(color: .brand.opacity(0.25), radius: 16, y: 8)

            HStack {
                Button { router.open(.chat(p.negotiationId)) } label: { Label("Chat with Driver", systemImage: "bubble.left") }
                Spacer()
                if p.status == "locked" && d.status == "active" {
                    Button("Leave", role: .destructive) { leaving = p }
                }
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: Driver pickup list

    @ViewBuilder private func driverView(_ d: Drive) -> some View {
        let ps = d.passengers.sorted { $0.time < $1.time }
        if !d.activeRiders.isEmpty {
            Map(initialPosition: .automatic) {
                ForEach(Array(d.activeRiders.enumerated()), id: \.element.id) { i, p in
                    Marker("\(i + 1). \(Fmt.clock(p.time))", monogram: Text("\(i + 1)"), coordinate: p.pickup.coordinate)
                        .tint(p.status == "locked" ? Color.highlight : Color.green)
                }
                if d.routeCoordinates.count > 1 { MapPolyline(coordinates: d.routeCoordinates).stroke(Color.brand.opacity(0.6), lineWidth: 4) }
            }
        .safeAreaPadding(8)
            .frame(height: 240)
            .clipShape(.rect(cornerRadius: 18))
            .accessibilityLabel("Pickups in order")
        }
        Text("Pickups in order").font(.title3.weight(.semibold))
        ForEach(Array(ps.enumerated()), id: \.element.id) { i, p in
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Text("\(i + 1)")
                        .font(.headline.monospacedDigit())
                        .frame(width: 36, height: 36)
                        .background(p.status == "locked" ? Color.highlight : p.status == "left" ? Color(.tertiarySystemFill) : Color.green.opacity(0.8), in: .circle)
                        .foregroundStyle(.black)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Rider \(Fmt.shortId(p.rider)) · \(Fmt.clock(p.time))").font(.headline)
                        StatusBadge(text: statusLabel(p.status), color: p.status == "boarded" ? .green : p.status == "locked" ? .orange : .secondary)
                    }
                    Spacer()
                    SafetyMenu(subject: p.rider, who: "rider \(Fmt.shortId(p.rider))").labelStyle(.iconOnly)
                }
                if (p.status == "locked" || p.status == "boarded") && d.status == "active" {
                    HStack(spacing: 8) {
                        if p.status == "locked" {
                            Button("Enter PIN") { boarding = p }.buttonStyle(.borderedProminent)
                        } else {
                            Button("Complete Drop-off") { dropping = p }.buttonStyle(.borderedProminent).tint(.green)
                        }
                        Button { router.open(.chat(p.negotiationId)) } label: { Label("Chat", systemImage: "bubble.left") }.buttonStyle(.bordered)
                        Spacer()
                        if p.status == "locked" { Button("Remove", role: .destructive) { leaving = p }.buttonStyle(.borderless) }
                    }
                    .controlSize(.small)
                }
            }
            .padding(14)
            .cardStyle()
        }
    }

    private func statusLabel(_ s: String) -> String {
        ["locked": "Waiting at pickup", "boarded": "On board", "completed": "Dropped off", "dropped": "Dropped off", "left": "Left"][s] ?? s.capitalized
    }

    private func load() async {
        do { drive = try await model.get(Drive.self, "/carpools/" + id); error = nil }
        catch { if drive == nil { self.error = error.localizedDescription } }
    }

    private func getPin() async {
        pinBusy = true
        defer { pinBusy = false }
        do { withAnimation { pin = nil }; let r = try await model.get(PinResult.self, "/carpools/\(id)/pin", method: "POST"); withAnimation { pin = r.pin } }
        catch { toast = Toast(text: error.localizedDescription, isError: true) }
    }

    private func dropoff(_ p: Passenger?) async {
        guard let p else { return }
        let loc = await LocationSnapshot.here(fallback: p.pickup)
        do {
            try await model.send("/carpools/\(id)/dropoff", body: ["rider": p.rider, "location": loc.point.json])
            toast = Toast(text: "Drop-off complete")
            await load()
        } catch { toast = Toast(text: error.localizedDescription, isError: true) }
    }

    private func leave(_ p: Passenger?) async {
        guard let p else { return }
        do {
            try await model.send("/carpools/\(id)/leave", body: ["rider": p.rider])
            toast = Toast(text: driver ? "Rider removed" : "You left the carpool")
            model.revision += 1
            await load()
        } catch { toast = Toast(text: error.localizedDescription, isError: true) }
    }
}

struct BoardSheet: View {
    let rideId: String
    let passenger: Passenger
    var onDone: (String) -> Void
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    @State private var busy = false
    @State private var error: String?
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Ask rider \(Fmt.shortId(passenger.rider)) to show their boarding pass. We save one location snapshot when they board.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                TextField("0000", text: $code)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .font(.system(size: 44, weight: .bold, design: .monospaced))
                    .tracking(16)
                    .multilineTextAlignment(.center)
                    .focused($focused)
                    .padding(.vertical, 12)
                    .background(Color(.tertiarySystemFill), in: .rect(cornerRadius: 14))
                    .onChange(of: code) { _, v in code = String(v.filter(\.isNumber).prefix(4)) }
                    .accessibilityLabel("4 digit PIN")
                if let error { Label(error, systemImage: "xmark.octagon.fill").foregroundStyle(.red) }
                Button { Task { await board() } } label: {
                    HStack { Spacer(); if busy { ProgressView() } else { Text("Board Rider").bold() }; Spacer() }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(code.count != 4 || busy)
                Spacer()
            }
            .padding(24)
            .navigationTitle("Boarding PIN")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .onAppear { focused = true }
            .sensoryFeedback(.error, trigger: error)
        }
        .presentationDetents([.medium])
    }

    private func board() async {
        busy = true; error = nil
        defer { busy = false }
        let loc = await LocationSnapshot.here(fallback: passenger.pickup)
        do {
            let data = try await model.send("/carpools/\(rideId)/board", body: ["rider": passenger.rider, "pin": code, "location": loc.point.json])
            if let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any], j["invalid"] as? Bool == true {
                error = "Wrong PIN. Ask the rider to check their pass."
                code = ""
                return
            }
            onDone(loc.approximate ? "Boarded (location approximate)" : "Rider boarded")
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}
