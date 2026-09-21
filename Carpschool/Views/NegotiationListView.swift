import SwiftUI

/**
 * NegotiationListView
 * 
 * Lists active negotiations and carpool coordination chats for riders and drivers.
 */
struct NegotiationListView: View {
    @Environment(AppState.self) private var appState
    
    @State private var negotiations: [Negotiation] = []
    @State private var isLoading: Bool = false

    var body: some View {
        List {
            Section {
                if negotiations.isEmpty && !isLoading {
                    ContentUnavailableView(
                        "No Active Negotiations",
                        systemImage: "bubble.left.and.bubble.right",
                        description: Text("When you reach out to a rider or driver, your conversations and pickup point proposals will appear here.")
                    )
                } else {
                    ForEach(negotiations) { neg in
                        NavigationLink(destination: NegotiationChatView(negotiation: neg)) {
                            HStack(spacing: 12) {
                                Image(systemName: "person.circle.fill")
                                    .font(.largeTitle)
                                    .foregroundStyle(Color.accentColor)

                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(appState.activeRole == .driver ? "Rider: Sam K." : "Driver: Alex W.")
                                            .font(.headline)
                                        Spacer()
                                        Text(neg.status)
                                            .font(.caption2.bold())
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.blue.opacity(0.15))
                                            .foregroundStyle(Color.blue)
                                            .clipShape(Capsule())
                                    }

                                    Label(neg.direction.displayName, systemImage: neg.direction.iconName)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)

                                    if let lastProp = neg.proposals.last {
                                        Text("Pickup: \(lastProp.pickupPointName) (\(lastProp.proposedTime))")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            } header: {
                HStack {
                    Text("Conversations & Proposals")
                    Spacer()
                    if isLoading { ProgressView() }
                }
            } footer: {
                Text("All negotiations adhere to Carpschool's zero-payment and verified student safety rules.")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Messages")
        .task {
            await loadNegotiations()
        }
    }

    private func loadNegotiations() async {
        isLoading = true
        // Seed sample active negotiation
        negotiations = [
            Negotiation(
                _id: "neg_active_1",
                applicationId: "app_ubc_1",
                driverId: "driver_alex",
                riderId: "rider_sam",
                direction: .homeToSchool,
                status: "NEGOTIATING",
                targetDate: ISO8601DateFormatter().string(from: Date()),
                proposals: [
                    Proposal(
                        proposalId: "prop_sample_1",
                        pickupPointName: "3600 W Broadway, Vancouver, BC",
                        pickupCoordinates: [-123.1856, 49.2642],
                        proposedTime: "08:30 AM",
                        status: .pending,
                        proposedBy: "driver"
                    )
                ],
                messages: [
                    ChatMessage(
                        _id: "msg_init",
                        senderId: "driver_alex",
                        senderName: "Alex W. (Driver)",
                        message: "Hi! I see your application for Broadway & Alma. I can pick you up near the bus loop.",
                        timestamp: "Today 7:45 AM",
                        isSystem: false
                    )
                ]
            )
        ]
        isLoading = false
    }
}
