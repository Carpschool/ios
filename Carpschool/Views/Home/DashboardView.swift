import SwiftUI

struct DashboardView: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @State private var homes: [Home]?
    @State private var requests: [Commute]?
    @State private var drives: [Drive]?
    @State private var offers: [RiderOffer] = []
    @State private var pools: [Drive]?
    @State private var error: String?
    @State private var cancelTarget: Commute?
    @State private var addHome = false
    @State private var toast: Toast?

    private var driver: Bool { model.isDriver }
    private var today: [Drive] { (pools ?? []).filter { $0.isUpcoming && $0.runsToday } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.school?.name ?? "").font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
                    Text("\(greeting), \(model.me?.name?.split(separator: " ").first.map(String.init) ?? "there")")
                        .font(.largeTitle.bold())
                }

                if let homes, homes.isEmpty {
                    Button { addHome = true } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "house.badge.plus").font(.title).foregroundStyle(.brand)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Add your home").font(.headline).foregroundStyle(.primary)
                                Text("Pickups are matched to where you live.").font(.subheadline).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                        }
                        .padding(16)
                        .cardStyle()
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader("Today")
                    if pools == nil && error == nil {
                        ProgressView().frame(maxWidth: .infinity, minHeight: 60)
                    } else if today.isEmpty {
                        Text("No carpools today.").foregroundStyle(.secondary)
                    } else {
                        ForEach(today) { p in
                            let first = (driver ? p.activeRiders : p.passengers).min { $0.time < $1.time }
                            NavigationLink(value: Route.ride(p.id)) {
                                TicketCard(accent: .green, stubTop: "PICKUP", stubValue: Fmt.clock(first?.time ?? p.startTime)) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(p.direction.label).font(.headline)
                                        Text(driver ? "\(p.activeRiders.count) rider\(p.activeRiders.count == 1 ? "" : "s") · pickup order" : "Tap for your boarding PIN")
                                            .font(.subheadline).foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if !driver && !offers.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader("Drivers reaching out")
                        ForEach(offers) { o in
                            NavigationLink(value: Route.chat(o.negotiationId)) {
                                TicketCard(accent: .highlight) {
                                    HStack {
                                        Image(systemName: "bubble.left.fill").foregroundStyle(.highlight)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("A driver wants to pick you up").font(.headline)
                                            Text("Agree on a pickup spot and time").font(.subheadline).foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: driver ? "Your drives" : "Your requests") {
                        NavigationLink(value: driver ? Route.newDrive : Route.newRequest) {
                            Label(driver ? "Post Drive" : "Request", systemImage: "plus")
                                .font(.subheadline.weight(.semibold))
                        }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.capsule)
                        .controlSize(.small)
                        .disabled(homes?.isEmpty ?? true)
                    }
                    if let error {
                        ErrorBanner(message: error) { Task { await load() } }
                    } else if driver {
                        driveList
                    } else {
                        requestList
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: Route.homes) { Text("My Homes") }
            }
        }
        .refreshable { await load() }
        .task(id: model.revision) { await load() }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(20))
                await loadLive()
            }
        }
        .sheet(isPresented: $addHome) {
            HomeEditorView(target: .new) { msg in toast = Toast(text: msg); Task { await load() } }
        }
        .confirmationDialog("Cancel this request?", isPresented: .init(get: { cancelTarget != nil }, set: { if !$0 { cancelTarget = nil } }), titleVisibility: .visible) {
            Button("Cancel Request", role: .destructive) { let r = cancelTarget; Task { await cancel(r) } }
        } message: { Text("Drivers will no longer see it.") }
        .toast($toast)
    }

    @ViewBuilder private var driveList: some View {
        let list = (drives ?? []).filter { $0.status == "active" }
        if drives == nil {
            ProgressView().frame(maxWidth: .infinity, minHeight: 80)
        } else if list.isEmpty {
            empty(icon: "car", title: "No drives posted", text: "Post your usual commute and we'll show riders along the way.")
        } else {
            ForEach(list) { d in
                NavigationLink(value: Route.drive(d.id)) {
                    TicketCard(stubTop: "SEATS", stubValue: "\(d.availableSeats)/\(d.seats)") {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(d.direction.label) · \(homeName(d.homeId))").font(.headline)
                            Text("\(d.schedule) · \(d.window)").font(.subheadline).foregroundStyle(.secondary)
                            StatusBadge(text: "Find riders", color: .brand).padding(.top, 2)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder private var requestList: some View {
        let list = (requests ?? []).filter { $0.status == "active" || $0.status == "locked" }
        if requests == nil {
            ProgressView().frame(maxWidth: .infinity, minHeight: 80)
        } else if list.isEmpty {
            empty(icon: "hourglass", title: "No ride requests", text: "Tell drivers when you need to get to school or home.")
        } else {
            ForEach(list) { r in
                TicketCard(accent: r.status == "locked" ? .green : .highlight, stubTop: r.direction == .toSchool ? "ARRIVE" : "LEAVE", stubValue: Fmt.clock(r.startTime)) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(r.direction.label) · \(homeName(r.homeId))").font(.headline)
                            Text("\(r.schedule) · \(r.window)").font(.subheadline).foregroundStyle(.secondary)
                            StatusBadge(text: r.status == "locked" ? "Carpool locked" : "Waiting for drivers", color: r.status == "locked" ? .green : .secondary).padding(.top, 2)
                        }
                        Spacer(minLength: 0)
                        if r.status == "active" {
                            Menu {
                                Button("Cancel Request", systemImage: "xmark", role: .destructive) { cancelTarget = r }
                            } label: {
                                Image(systemName: "ellipsis").frame(width: 28, height: 28).contentShape(.rect)
                            }
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Request options")
                        }
                    }
                }
                .contextMenu {
                    if r.status == "active" { Button("Cancel Request", systemImage: "xmark", role: .destructive) { cancelTarget = r } }
                }
            }
        }
    }

    private func empty(icon: String, title: String, text: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.largeTitle).foregroundStyle(.tertiary)
            Text(title).font(.headline)
            Text(text).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .cardStyle()
    }

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: .now)
        return h < 12 ? "Good morning" : h < 18 ? "Good afternoon" : "Good evening"
    }

    private func homeName(_ id: String) -> String { homes?.first { $0.id == id }?.label ?? "Home" }

    private func load() async {
        do {
            async let h = model.get([Home].self, "/homes")
            if driver { drives = try await model.get([Drive].self, "/drives") }
            else { requests = try await model.get([Commute].self, "/requests") }
            homes = try await h
            error = nil
            await loadLive()
        } catch { self.error = error.localizedDescription }
    }

    private func loadLive() async {
        pools = (try? await model.get([Drive].self, "/carpools")) ?? pools
        if !driver { offers = (try? await model.get([RiderOffer].self, "/matches")) ?? offers }
    }

    private func cancel(_ r: Commute?) async {
        guard let r else { return }
        do { try await model.send("/requests/" + r.id, method: "DELETE"); toast = Toast(text: "Request cancelled"); await load() }
        catch { toast = Toast(text: error.localizedDescription, isError: true) }
    }
}
