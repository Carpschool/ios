import SwiftUI
import MapKit

struct NegotiationChatView: View {
    @State private var showLocationModal = false
    @State private var messageText = ""

    var body: some View {
        VStack {
            HStack {
                Text("Chat & Pickup Negotiation").font(.headline)
                Spacer()
                Button {
                    showLocationModal = true
                } label: {
                    Label("Suggest Pickup", systemImage: "mappin.and.ellipse")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
            }
            .padding()

            ScrollView {
                VStack(spacing: 12) {
                    Text("// TODO: Connect to Socket.io negotiation room and render chat stream")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding()

                    // Sample In-Chat Proposal Card
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("📍 Proposed Pickup").font(.caption).bold().foregroundStyle(.blue)
                            Spacer()
                            Text("PENDING").font(.caption2).padding(4).background(Color.yellow.opacity(0.2)).cornerRadius(4)
                        }
                        Text("Corner of 10th & Main").font(.subheadline).bold()
                        Text("Pickup Time: 08:30 AM").font(.caption).foregroundStyle(.secondary)

                        HStack {
                            Button("Confirm") {
                                // TODO: Confirm proposal
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.green)
                            .controlSize(.small)

                            Button("Deny") {
                                // TODO: Deny proposal
                            }
                            .buttonStyle(.bordered)
                            .tint(.red)
                            .controlSize(.small)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
            }

            HStack {
                TextField("Type a message...", text: $messageText)
                    .textFieldStyle(.roundedBorder)
                Button(action: {
                    // TODO: Send message
                    messageText = ""
                }) {
                    Image(systemName: "paperplane.fill")
                }
            }
            .padding()
        }
        .sheet(isPresented: $showLocationModal) {
            NavigationStack {
                VStack {
                    Text("Select a pickup point within the rider's walking radius (10m - 200m).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding()

                    Map {
                        Marker("Agreed Pickup", coordinate: CLLocationCoordinate2D(latitude: 49.2606, longitude: -123.246))
                    }

                    Button("Send Location Proposal") {
                        showLocationModal = false
                        // TODO: Submit proposal to School Server
                    }
                    .buttonStyle(.borderedProminent)
                    .padding()
                }
                .navigationTitle("Suggest Pickup Point")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
    }
}
