import SwiftUI

/**
 * NewApplicationSheet
 * 
 * Form to post a new rider commute request.
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
                Section("Route and Schedule") {
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
                            Text("\(Int(walkingRadius)) m")
                                .bold()
                                .foregroundStyle(Color.accentColor)
                        }
                        Slider(value: $walkingRadius, in: 10...200, step: 5)
                        HStack {
                            Text("10 m (doorstep)").font(.caption2).foregroundStyle(.secondary)
                            Spacer()
                            Text("200 m (short walk)").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
                
                Section("Notes for Drivers") {
                    TextField("Luggage, sports gear, preferred meeting area", text: $notes)
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
