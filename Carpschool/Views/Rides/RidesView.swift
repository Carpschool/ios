import SwiftUI

struct RidesView: View {
    @Environment(AppModel.self) private var model
    @State private var pools: [Drive]?
    @State private var error: String?
    @State private var showPast = false

    private var upcoming: [Drive] { (pools ?? []).filter(\.isUpcoming) }
    private var past: [Drive] { (pools ?? []).filter { !$0.isUpcoming } }

    var body: some View {
        Group {
            if let pools {
                if pools.isEmpty {
                    ContentUnavailableView("No rides yet", systemImage: "car.2",
                                           description: Text("Once you and a \(model.isDriver ? "rider" : "driver") agree on a pickup, your ride shows up here."))
                } else {
                    List {
                        Picker("Show", selection: $showPast) {
                            Text("Upcoming").tag(false)
                            Text("History").tag(true)
                        }
                        .pickerStyle(.segmented)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                        let list = showPast ? past : upcoming
                        if list.isEmpty {
                            Text(showPast ? "No past rides." : "No upcoming rides.").foregroundStyle(.secondary)
                        }
                        ForEach(list) { d in
                            NavigationLink(value: Route.ride(d.id)) { row(d) }
                        }
                    }
                }
            } else if let error {
                ErrorBanner(message: error) { Task { await load() } }
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Rides")
        .task(id: model.revision) { await load() }
        .refreshable { await load() }
    }

    private func row(_ d: Drive) -> some View {
        let mine = model.isDriver ? d.activeRiders : d.passengers
        let first = mine.min { $0.time < $1.time }
        return HStack(spacing: 14) {
            VStack(spacing: 0) {
                Text(Fmt.clock(first?.time ?? d.startTime)).font(.headline.monospacedDigit())
                Text("pickup").font(.caption2).foregroundStyle(.secondary)
            }
            .frame(width: 74)
            VStack(alignment: .leading, spacing: 3) {
                Text(d.direction.label).font(.headline)
                Text(d.schedule).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            if d.status != "active" { StatusBadge(text: d.status.capitalized) }
            else if d.isUpcoming && d.runsToday { StatusBadge(text: "Today", color: .brand) }
            else if !model.isDriver, let s = first?.status, s != "locked" { StatusBadge(text: s.capitalized) }
        }
        .padding(.vertical, 4)
    }

    private func load() async {
        do { pools = try await model.get([Drive].self, "/carpools"); error = nil }
        catch { self.error = error.localizedDescription }
    }
}
