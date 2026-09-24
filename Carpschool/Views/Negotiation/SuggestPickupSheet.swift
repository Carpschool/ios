import SwiftUI
import MapKit

/**
 * SuggestPickupSheet
 * 
 * Native Apple MapKit location suggestion sheet for in-chat pickup point proposals.
 */
struct SuggestPickupSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onProposalSubmitted: (Proposal) -> Void

    @State private var locationName: String = "10th & Alma Transit Loop"
    @State private var pickupDate: Date = Date()
    @State private var pickedCoordinate = CLLocationCoordinate2D(latitude: 49.2642, longitude: -123.1856)
    @State private var position: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 49.2642, longitude: -123.1856),
            latitudinalMeters: 1000,
            longitudinalMeters: 1000
        )
    )

    var body: some View {
        NavigationStack {
            Form {
                Section("Pickup Spot") {
                    TextField("Bus loop, corner, loading zone", text: $locationName)
                    DatePicker("Pickup Time", selection: $pickupDate, displayedComponents: [.hourAndMinute])
                }

                Section("Location on Apple Maps") {
                    Text("Select a safe curb, passenger loading zone, or transit loop.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Map(position: $position) {
                        Marker(locationName, coordinate: pickedCoordinate)
                            .tint(Color.accentColor)
                    }
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                Section {
                    Button {
                        submit()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Send Proposal")
                                .bold()
                            Spacer()
                        }
                    }
                    .disabled(locationName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .navigationTitle("Suggest Pickup Point")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func submit() {
        let formatter = DateFormatter()
        formatter.dateFormat = "hh:mm a"
        let timeStr = formatter.string(from: pickupDate)

        let prop = Proposal(
            proposalId: "prop_\(UUID().uuidString.prefix(6))",
            pickupPointName: locationName,
            pickupCoordinates: [pickedCoordinate.longitude, pickedCoordinate.latitude],
            proposedTime: timeStr,
            status: .pending,
            proposedBy: "me"
        )
        onProposalSubmitted(prop)
        dismiss()
    }
}
