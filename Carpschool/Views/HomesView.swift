import SwiftUI
import MapKit

struct HomesView: View {
    @State private var label: String = "Primary Home"
    @State private var address: String = "1234 Student Blvd, Vancouver, BC"
    @State private var walkingRadius: Double = 75 // 10m to 200m
    @State private var homes: [UserHome] = []

    var body: some View {
        Form {
            Section("Add New Location") {
                TextField("Label (e.g. Home, Dorm)", text: $label)
                TextField("Street Address", text: $address)

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Walking Radius")
                        Spacer()
                        Text("\(Int(walkingRadius)) meters")
                            .bold()
                            .foregroundStyle(.blue)
                    }
                    Slider(value: $walkingRadius, in: 10...200, step: 5)
                    HStack {
                        Text("10m (doorstep)").font(.caption2).foregroundStyle(.secondary)
                        Spacer()
                        Text("200m (short walk)").font(.caption2).foregroundStyle(.secondary)
                    }
                }

                Button("Save Location") {
                    // TODO: Call NetworkService.shared.saveHome(...)
                    let newHome = UserHome(
                        _id: UUID().uuidString,
                        label: label,
                        address: address,
                        walkingRadiusMeters: Int(walkingRadius),
                        location: GeoLocation(type: "Point", coordinates: [-123.246, 49.2606])
                    )
                    homes.append(newHome)
                }
            }

            Section("Saved Locations") {
                if homes.isEmpty {
                    Text("No saved locations yet.").foregroundStyle(.secondary)
                } else {
                    ForEach(homes) { home in
                        VStack(alignment: .leading) {
                            Text(home.label).font(.headline)
                            Text(home.address).font(.caption).foregroundStyle(.secondary)
                            Text("Walking radius: \(home.walkingRadiusMeters) meters")
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }
                    }
                }
            }
        }
        .navigationTitle("Saved Homes")
    }
}
