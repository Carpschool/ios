import SwiftUI
import MapKit

struct ChatView: View {
    let id: String
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @State private var socket: ChatSocket
    @State private var negotiation: Negotiation?
    @State private var defaultSpot: CLLocationCoordinate2D?
    @State private var text = ""
    @State private var proposing: ProposalSheet.Draft?
    @State private var pin: String?
    @State private var toast: Toast?
    @State private var error: String?
    @FocusState private var composing: Bool

    init(id: String) {
        self.id = id
        _socket = State(initialValue: ChatSocket(negotiationId: id))
    }

    private enum Item: Identifiable {
        case message(ChatMessage), proposal(Proposal)
        var id: String { switch self { case .message(let m): "m" + m.id; case .proposal(let p): "p" + p.id } }
        var at: String { switch self { case .message(let m): m.createdAt; case .proposal(let p): p.createdAt } }
    }

    private var items: [Item] {
        (socket.messages.map(Item.message) + socket.proposals.map(Item.proposal)).sorted { $0.at < $1.at }
    }
    private var me: String { model.me?.sub ?? "" }
    private var other: String { negotiation.map { model.isDriver ? $0.rider : $0.driver } ?? "" }
    private var isOpen: Bool { negotiation?.status == "open" && socket.lockedDrive == nil }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    if negotiation != nil && items.isEmpty {
                        Label("Say hi, then send a pickup proposal with a spot and a time.", systemImage: "mappin.and.ellipse")
                            .font(.subheadline).foregroundStyle(.secondary)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .cardStyle()
                    }
                    ForEach(items) { item in
                        switch item {
                        case .message(let m): bubble(m).id(item.id)
                        case .proposal(let p): proposalCard(p).id(item.id)
                        }
                    }
                    if let drive = socket.lockedDrive ?? (negotiation?.status == "locked" ? negotiation?.driveId : nil) {
                        Button { router.open(.ride(drive)) } label: {
                            Label("Carpool locked · View ride", systemImage: "checkmark.seal.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(.green)
                        .id("locked")
                    }
                    Color.clear.frame(height: 1).id("end")
                }
                .padding()
            }
            .defaultScrollAnchor(.bottom)
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: items.count) { withAnimation { proxy.scrollTo("end") } }
        }
        .background(Color(.systemGroupedBackground))
        .safeAreaInset(edge: .bottom) {
            if isOpen { composer }
            else if let n = negotiation, n.status != "locked", socket.lockedDrive == nil {
                Label(n.status == "cancelled" ? "This chat closed when the ride was cancelled." : "This chat is closed.", systemImage: "lock")
                    .font(.footnote).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity).padding(.vertical, 12).background(.bar)
            }
        }
        .navigationTitle(negotiation == nil ? "Chat" : "\(model.isDriver ? "Rider" : "Driver") \(Fmt.shortId(other))")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 0) {
                    Text(negotiation == nil ? "Chat" : "\(model.isDriver ? "Rider" : "Driver") \(Fmt.shortId(other))").font(.headline)
                    HStack(spacing: 4) {
                        Circle().fill(socket.state == .live ? Color.green : Color.secondary).frame(width: 6, height: 6)
                        Text(socket.state == .live ? "Live" : socket.state == .connecting ? "Connecting…" : "Offline").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .combine)
            }
            ToolbarItem(placement: .topBarTrailing) {
                if !other.isEmpty { SafetyMenu(subject: other, who: "\(model.isDriver ? "rider" : "driver") \(Fmt.shortId(other))") { router.chats = NavigationPath() } }
            }
        }
        .sheet(item: $proposing) { d in
            ProposalSheet(draft: d) { coord, time in await propose(coord, time) }
        }
        .alert("You're in", isPresented: .init(get: { pin != nil }, set: { if !$0 { pin = nil } })) {
            Button("View Boarding Pass") { if let d = socket.lockedDrive { router.open(.ride(d)) } }
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your boarding PIN is \(pin ?? ""). Show it to your driver at pickup.")
        }
        .onChange(of: socket.lastError) { _, e in if let e { toast = Toast(text: e, isError: true); socket.lastError = nil } }
        .onChange(of: socket.lockedDrive) { _, d in if d != nil { Task { await reloadNegotiation() } } }
        .task { await start() }
        .onDisappear { socket.disconnect() }
        .toast($toast)
    }

    private func bubble(_ m: ChatMessage) -> some View {
        let mine = m.author == me
        return HStack {
            if mine { Spacer(minLength: 48) }
            VStack(alignment: mine ? .trailing : .leading, spacing: 2) {
                Text(m.text)
                Text(Fmt.date(m.createdAt)?.formatted(date: .omitted, time: .shortened) ?? "")
                    .font(.caption2).opacity(0.6)
            }
            .padding(.horizontal, 14).padding(.vertical, 9)
            .foregroundStyle(mine ? Color.white : Color.primary)
            .background(mine ? Color.brand : Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 18))
            if !mine { Spacer(minLength: 48) }
        }
    }

    private func proposalCard(_ p: Proposal) -> some View {
        let mine = p.author == me
        return HStack {
            if mine { Spacer(minLength: 40) }
            VStack(spacing: 0) {
                PinMap(coordinate: p.pickup.coordinate, height: 130)
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(mine ? "YOUR PROPOSAL" : "PICKUP PROPOSAL").font(.caption2.weight(.semibold)).foregroundStyle(.secondary).tracking(0.8)
                        Text(Fmt.clock(p.time)).font(.title2.monospacedDigit().bold())
                    }
                    Spacer()
                    if p.status == "accepted" {
                        StatusBadge(text: "Accepted", color: .green)
                    } else if p.status != "pending" {
                        StatusBadge(text: p.status.capitalized)
                    } else if mine {
                        StatusBadge(text: "Waiting")
                    } else if isOpen {
                        Button("Counter") { proposing = .init(title: "Counter", coordinate: p.pickup.coordinate, time: p.time) }
                            .buttonStyle(.bordered).controlSize(.small)
                        Button("Accept") { Task { await accept(p) } }
                            .buttonStyle(.borderedProminent).controlSize(.small).tint(.green)
                    }
                }
                .padding(12)
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(.rect(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(p.status == "accepted" ? Color.green : Color.highlight, lineWidth: 2))
            .frame(maxWidth: 330)
            if !mine { Spacer(minLength: 40) }
        }
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Button {
                proposing = .init(title: "Propose Pickup", coordinate: defaultSpot ?? model.meta?.campusPoint.coordinate, time: model.isDriver ? "07:45" : "07:45")
            } label: {
                Image(systemName: "mappin.and.ellipse")
                    .font(.title3.weight(.semibold))
                    .frame(width: 40, height: 40)
                    .foregroundStyle(.black)
                    .background(Color.highlight, in: .circle)
            }
            .accessibilityLabel("Propose pickup spot and time")
            TextField("Message", text: $text, axis: .vertical)
                .lineLimit(1...4)
                .focused($composing)
                .padding(.horizontal, 14).padding(.vertical, 9)
                .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 20))
                .onSubmit { Task { await sendMessage() } }
            Button { Task { await sendMessage() } } label: {
                Image(systemName: "arrow.up.circle.fill").font(.system(size: 34))
            }
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityLabel("Send")
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(.bar)
    }

    private func start() async {
        await reloadNegotiation()
        async let msgs = model.get([ChatMessage].self, "/negotiations/\(id)/messages")
        async let props = model.get([Proposal].self, "/negotiations/\(id)/proposals")
        if let m = try? await msgs { socket.messages = m }
        if let p = try? await props { socket.proposals = p }
        if model.isDriver, let n = negotiation, let d = try? await model.get(Drive.self, "/drives/" + n.driveId) {
            defaultSpot = d.routeCoordinates.first
        } else if !model.isDriver, let h = try? await model.get([Home].self, "/homes") {
            defaultSpot = h.first?.location.coordinate
        }
        guard let base = model.school?.baseUrl else { return }
        await socket.connect(baseURL: base) { [model] in try await model.socketToken() }
    }

    private func reloadNegotiation() async {
        do { negotiation = try await model.get(Negotiation.self, "/negotiations/" + id) }
        catch { toast = Toast(text: error.localizedDescription, isError: true) }
    }

    private func sendMessage() async {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        text = ""
        do {
            let r = try await socket.emit("message:send", ["text": String(t.prefix(2000))])
            if let m: ChatMessage = ChatSocket.decode(r), !socket.messages.contains(where: { $0.id == m.id }) { socket.messages.append(m) }
        } catch {
            text = t
            toast = Toast(text: error.localizedDescription, isError: true)
        }
    }

    private func propose(_ c: CLLocationCoordinate2D, _ time: String) async -> Bool {
        do {
            let r = try await socket.emit("proposal:send", ["pickup": GeoPoint(c).json, "time": time])
            if let p: Proposal = ChatSocket.decode(r) { socket.upsert(p) }
            if let p = try? await model.get([Proposal].self, "/negotiations/\(id)/proposals") { socket.proposals = p }
            return true
        } catch {
            toast = Toast(text: error.localizedDescription, isError: true)
            return false
        }
    }

    private func accept(_ p: Proposal) async {
        do {
            let r = try await socket.emit("proposal:accept", ["proposalId": p.id])
            let res: AcceptResult? = ChatSocket.decode(r)
            socket.lockedDrive = res?.driveId
            if let pin = res?.pin { self.pin = pin } else { toast = Toast(text: "Seat locked. Your rider is confirmed.") }
            if let ps = try? await model.get([Proposal].self, "/negotiations/\(id)/proposals") { socket.proposals = ps }
            model.revision += 1
        } catch { toast = Toast(text: error.localizedDescription, isError: true) }
    }
}
