import SwiftUI

/**
 * RiderApplicationsView
 * 
 * Student Rider Commute Application Management.
 * Features:
 * - Active requests list with direction, target time, and status badges
 * - "New Commute Request" modal sheet with DatePicker and walking radius slider
 * - Zero payments, pure reciprocal student matching
 */
struct RiderApplicationsView: View {
    @Environment(AppState.self) private var appState
    
    @State private var applications: [RiderApplication] = []
    @State private var showNewAppSheet: Bool = false
    @State private var isLoading: Bool = false

    var body: some View {
        List {
            Section {
                if applications.isEmpty && !isLoading {
                    ContentUnavailableView(
                        "No Commute Requests",
                        systemImage: "car.side.front.open",
                        description: Text("Post when and where you need a ride to campus. Student drivers along your route will be able to reach out.")
                    )
                } else {
                    ForEach(applications) { app in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Label(app.direction.displayName, systemImage: app.direction.iconName)
                                    .font(.headline)
                                    .foregroundStyle(Color.accentColor)
                                Spacer()
                                Text(app.status ?? "OPEN")
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.green.opacity(0.15))
                                    .foregroundStyle(.green)
                                    .clipShape(Capsule())
                            }
                            
                            HStack {
                                Label(app.targetTime, systemImage: "clock")
                                    .font(.subheadline)
                                Spacer()
                                Label(app.scheduleType.displayName, systemImage: "repeat")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            HStack {
                                Label("\(app.walkingRadiusMeters) m walking radius", systemImage: "figure.walk")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            
                            if let notes = app.notes, !notes.isEmpty {
                                Text("\"\(notes)\"")
                                    .font(.caption)
                                    .italic()
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            } header: {
                HStack {
                    Text("Active Requests")
                    Spacer()
                    if isLoading { ProgressView() }
                }
            } footer: {
                Text("When a student driver reaches out, you will receive a pickup proposal to agree on an exact location.")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("My Rides")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showNewAppSheet = true
                } label: {
                    Label("Post Request", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showNewAppSheet) {
            NewApplicationSheet(onApplicationCreated: { newApp in
                applications.insert(newApp, at: 0)
            })
        }
        .task {
            await loadApplications()
        }
    }
    
    private func loadApplications() async {
        isLoading = true
        applications = [
            RiderApplication(
                _id: "app_rider_1",
                riderId: "rider_me",
                direction: .homeToSchool,
                scheduleType: .recurring,
                targetTime: "08:30 AM",
                walkingRadiusMeters: 75,
                pickupHome: appState.currentUserProfile?.primaryHome,
                status: "OPEN",
                notes: "Morning class at 9:00 AM"
            )
        ]
        isLoading = false
    }
}
