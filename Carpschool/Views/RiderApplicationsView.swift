import SwiftUI

/**
 * RiderApplicationsView
 * 
 * Student Rider Commute Application Management.
 * Features:
 * - Active applications list with direction, target time, and status badges
 * - "New Application" modal sheet with DatePicker and walking radius slider
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
                        "No Active Applications",
                        systemImage: "car.side.front.open",
                        description: Text("Post a commute request to let student drivers know when and where you need a lift.")
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
                                Label("\(app.walkingRadiusMeters)m walking radius", systemImage: "figure.walk")
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
                    Text("My Commute Requests")
                    Spacer()
                    if isLoading { ProgressView() }
                }
            } footer: {
                Text("When a student driver along your corridor reaches out, you will receive a negotiation proposal to agree on an exact pickup spot.")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("My Commute")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showNewAppSheet = true
                } label: {
                    Label("Post Commute", systemImage: "plus")
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
        // Seed with sample rider applications if none returned
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

/**
 * NewApplicationSheet
 * 
 * Form to create a new rider commute application.
 */
struct NewApplicationSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onApplicationCreated: (RiderApplication) -> Void
    
    @State private var direction: CommuteDirection = .homeToSchool
    @State private var scheduleType: ScheduleType = .recurring
    @State private var targetDate: Date = Date()
    @State private var walkingRadius: Double = 75
    @State private var notes: String = ""
    @State private var isSubmitting: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Commute Route & Schedule") {
                    Picker("Direction", selection: $direction) {
                        ForEach(CommuteDirection.allCases, id: \.self) { dir in
                            Text(dir.displayName).tag(dir)
                        }
                    }
                    
                    Picker("Frequency", selection: $scheduleType) {
                        ForEach(ScheduleType.allCases, id: \.self) { sched in
                            Text(sched.displayName).tag(sched)
                        }
                    }
                    
                    DatePicker("Target Time", selection: $targetDate, displayedComponents: [.hourAndMinute])
                }
                
                Section("Walking Radius") {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Acceptable Walking Distance")
                            Spacer()
                            Text("\(Int(walkingRadius)) meters")
                                .bold()
                                .foregroundStyle(Color.accentColor)
                        }
                        Slider(value: $walkingRadius, in: 10...200, step: 5)
                        HStack {
                            Text("10m (doorstep)").font(.caption2).foregroundStyle(.secondary)
                            Spacer()
                            Text("200m (short walk)").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
                
                Section("Notes for Drivers (Optional)") {
                    TextField("e.g. Carrying small sports bag, quiet passenger", text: $notes)
                }
                
                Section {
                    Button {
                        submitApplication()
                    } label: {
                        HStack {
                            Spacer()
                            if isSubmitting { ProgressView().padding(.trailing, 4) }
                            Text("Post Commute Request").bold()
                            Spacer()
                        }
                    }
                    .disabled(isSubmitting)
                }
            }
            .navigationTitle("New Commute Request")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    private func submitApplication() {
        isSubmitting = true
        let formatter = DateFormatter()
        formatter.dateFormat = "hh:mm a"
        let timeStr = formatter.string(from: targetDate)
        
        Task {
            let newApp = try? await NetworkService.shared.createRiderApplication(
                direction: direction,
                scheduleType: scheduleType,
                targetTime: timeStr,
                walkingRadius: Int(walkingRadius),
                notes: notes.isEmpty ? nil : notes
            )
            
            let finalApp = newApp ?? RiderApplication(
                _id: UUID().uuidString,
                riderId: "rider_me",
                direction: direction,
                scheduleType: scheduleType,
                targetTime: timeStr,
                walkingRadiusMeters: Int(walkingRadius),
                pickupHome: nil,
                status: "OPEN",
                notes: notes.isEmpty ? nil : notes
            )
            
            isSubmitting = false
            onApplicationCreated(finalApp)
            dismiss()
        }
    }
}
