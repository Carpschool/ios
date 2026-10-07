import SwiftUI
import MapKit

struct ProposalSheet: View {
    struct Draft: Identifiable {
        let title: String
        let coordinate: CLLocationCoordinate2D?
        let time: String
        var id: String { title + time }
    }
    let draft: Draft
    var onSend: (CLLocationCoordinate2D, String) async -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var camera: MapCameraPosition = .automatic
    @State private var center: CLLocationCoordinate2D?
    @State private var time = Date.now
    @State private var busy = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ZStack {
                    Map(position: $camera) { UserAnnotation() }
                        .onMapCameraChange(frequency: .continuous) { center = $0.region.center }
                        .mapControls { MapUserLocationButton() }
                    VStack(spacing: 0) {
                        Image(systemName: "figure.wave.circle.fill")
                            .font(.system(size: 40))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.black, Color.highlight)
                        Rectangle().fill(.black).frame(width: 2, height: 10)
                    }
                    .offset(y: -25)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                }
                Form {
                    DatePicker("Pickup time", selection: $time, displayedComponents: .hourAndMinute)
                    Text("Move the map so the pin sits on a safe, easy pickup spot.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                .frame(height: 150)
                .scrollDisabled(true)
            }
            .navigationTitle(draft.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    if busy { ProgressView() } else {
                        Button("Send") {
                            Task {
                                guard let center else { return }
                                busy = true
                                if await onSend(center, Fmt.hm.string(from: time)) { dismiss() }
                                busy = false
                            }
                        }
                        .disabled(center == nil)
                    }
                }
            }
            .onAppear {
                if let c = draft.coordinate { camera = .region(.init(center: c, latitudinalMeters: 500, longitudinalMeters: 500)) }
                else { camera = .userLocation(fallback: .automatic) }
                time = Fmt.hm.date(from: draft.time).flatMap { d in
                    let c = Calendar.current.dateComponents([.hour, .minute], from: d)
                    return Calendar.current.date(bySettingHour: c.hour ?? 7, minute: c.minute ?? 45, second: 0, of: .now)
                } ?? .now
            }
        }
        .presentationDetents([.large])
    }
}
