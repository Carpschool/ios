import SwiftUI
import MapKit

struct CorridorMatchingView: View {
    @State private var direction: CommuteDirection = .homeToSchool
    @State private var position: MapCameraPosition = .automatic

    var body: some View {
        VStack(spacing: 0) {
            Picker("Direction", selection: $direction) {
                Text("Home → School").tag(CommuteDirection.homeToSchool)
                Text("School → Home").tag(CommuteDirection.schoolToHome)
            }
            .pickerStyle(.segmented)
            .padding()

            Map(position: $position) {
                Marker("UBC Campus", coordinate: CLLocationCoordinate2D(latitude: 49.2606, longitude: -123.246))
                    .tint(.blue)

                // Sample rider application marker with walking circle
                Annotation("Rider Pickup", coordinate: CLLocationCoordinate2D(latitude: 49.268, longitude: -123.23)) {
                    VStack {
                        Image(systemName: "figure.wave").foregroundStyle(.purple)
                        Text("8:30 AM").font(.caption2).bold()
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Nearby Rider Applications").font(.headline).padding(.horizontal)
                Text("// TODO: Fetch applications along commute corridor and display Reach Out buttons")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle("Corridor Matching")
    }
}
