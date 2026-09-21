import SwiftUI
import MapKit

/**
 * NegotiationChatView
 * 
 * In-chat negotiation view with embedded Proposal Cards and interactive MapKit pickup point suggestions.
 */
struct NegotiationChatView: View {
    @State var negotiation: Negotiation
    @Environment(\.dismiss) private var dismiss
    
    @State private var messageText: String = ""
    @State private var showSuggestSheet: Bool = false
    @State private var messages: [ChatMessage] = []

    var body: some View {
        VStack(spacing: 0) {
            // Direction & Campus Header
            HStack {
                Label(negotiation.direction.displayName, systemImage: negotiation.direction.iconName)
                    .font(.caption.bold())
                    .foregroundStyle(Color.accentColor)
                Spacer()
                Text(negotiation.status)
                    .font(.caption2.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.15))
                    .foregroundStyle(Color.blue)
                    .clipShape(Capsule())
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.secondarySystemBackground))

            // Scrollable Chat & Proposal Feed
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        // Proposal Cards
                        ForEach(negotiation.proposals) { proposal in
                            ProposalCardView(
                                proposal: proposal,
                                onConfirm: { confirmProposal(proposal) },
                                onDeny: { denyProposal(proposal) }
                            )
                        }

                        // Chat Messages
                        ForEach(messages) { msg in
                            chatBubble(msg)
                                .id(msg.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: messages.count) { _, _ in
                    if let last = messages.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            // Chat Input Bar
            HStack(spacing: 10) {
                Button {
                    showSuggestSheet = true
                } label: {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.title3)
                        .foregroundStyle(Color.accentColor)
                }

                TextField("Type a message...", text: $messageText)
                    .textFieldStyle(.roundedBorder)

                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.title3)
                        .foregroundStyle(messageText.trimmingCharacters(in: .whitespaces).isEmpty ? Color.secondary : Color.accentColor)
                }
                .disabled(messageText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
        }
        .navigationTitle("Carpool Negotiation")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Suggest") {
                    showSuggestSheet = true
                }
            }
        }
        .sheet(isPresented: $showSuggestSheet) {
            SuggestPickupSheet(onProposalSubmitted: { newProp in
                negotiation.proposals.append(newProp)
                let sysMsg = ChatMessage(
                    _id: UUID().uuidString,
                    senderId: "system",
                    senderName: "System",
                    message: "New pickup point proposed: \(newProp.pickupPointName) at \(newProp.proposedTime).",
                    timestamp: "Just now",
                    isSystem: true
                )
                messages.append(sysMsg)
            })
        }
        .onAppear {
            if let msgs = negotiation.messages, !msgs.isEmpty {
                self.messages = msgs
            } else {
                self.messages = [
                    ChatMessage(
                        _id: "msg_init",
                        senderId: negotiation.driverId,
                        senderName: "Driver",
                        message: "Hello! I'm heading towards campus and proposed a convenient pickup spot.",
                        timestamp: "Today",
                        isSystem: false
                    )
                ]
            }
        }
    }

    private func chatBubble(_ msg: ChatMessage) -> some View {
        let isMe = msg.senderId == "driver_me" || msg.senderId == "rider_me"
        return HStack {
            if isMe { Spacer() }
            VStack(alignment: isMe ? .trailing : .leading, spacing: 3) {
                if let name = msg.senderName, !isMe {
                    Text(name).font(.caption2.bold()).foregroundStyle(.secondary)
                }
                Text(msg.message)
                    .font(.body)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(isMe ? Color.accentColor : Color(.secondarySystemBackground))
                    .foregroundStyle(isMe ? Color.white : Color.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                Text(msg.timestamp)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            if !isMe { Spacer() }
        }
    }

    private func sendMessage() {
        let text = messageText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        
        let newMsg = ChatMessage(
            _id: UUID().uuidString,
            senderId: "driver_me",
            senderName: "Me",
            message: text,
            timestamp: "Just now",
            isSystem: false
        )
        messages.append(newMsg)
        messageText = ""
    }

    private func confirmProposal(_ proposal: Proposal) {
        if let idx = negotiation.proposals.firstIndex(where: { $0.id == proposal.id }) {
            let updated = Proposal(
                proposalId: proposal.proposalId,
                pickupPointName: proposal.pickupPointName,
                pickupCoordinates: proposal.pickupCoordinates,
                proposedTime: proposal.proposedTime,
                status: .confirmed,
                proposedBy: proposal.proposedBy
            )
            negotiation.proposals[idx] = updated
            messages.append(
                ChatMessage(
                    _id: UUID().uuidString,
                    senderId: "system",
                    senderName: "System",
                    message: "🎉 Pickup proposal confirmed for \(proposal.pickupPointName) at \(proposal.proposedTime)!",
                    timestamp: "Just now",
                    isSystem: true
                )
            )
        }
    }

    private func denyProposal(_ proposal: Proposal) {
        if let idx = negotiation.proposals.firstIndex(where: { $0.id == proposal.id }) {
            let updated = Proposal(
                proposalId: proposal.proposalId,
                pickupPointName: proposal.pickupPointName,
                pickupCoordinates: proposal.pickupCoordinates,
                proposedTime: proposal.proposedTime,
                status: .denied,
                proposedBy: proposal.proposedBy
            )
            negotiation.proposals[idx] = updated
        }
    }
}

/**
 * ProposalCardView
 * 
 * Interactive proposal card embedded in negotiation stream.
 */
struct ProposalCardView: View {
    let proposal: Proposal
    var onConfirm: () -> Void
    var onDeny: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("📍 Proposed Pickup Point", systemImage: "mappin.circle.fill")
                    .font(.caption.bold())
                    .foregroundStyle(Color.accentColor)
                Spacer()
                statusBadge
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(proposal.pickupPointName)
                    .font(.headline)
                Text("Proposed Time: \(proposal.proposedTime)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Interactive Apple Map snapshot for proposed pickup
            Map {
                Marker(proposal.pickupPointName, coordinate: proposal.coordinate)
                    .tint(Color.accentColor)
            }
            .frame(height: 120)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            if proposal.status == .pending {
                HStack(spacing: 12) {
                    Button(action: onConfirm) {
                        HStack {
                            Image(systemName: "checkmark")
                            Text("Confirm")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .controlSize(.small)

                    Button(action: onDeny) {
                        HStack {
                            Image(systemName: "xmark")
                            Text("Deny")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .controlSize(.small)
                }
                .padding(.top, 4)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }

    private var statusBadge: some View {
        Text(proposal.status.rawValue)
            .font(.caption2.bold())
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                proposal.status == .confirmed ? Color.green.opacity(0.15) :
                (proposal.status == .denied ? Color.red.opacity(0.15) : Color.orange.opacity(0.15))
            )
            .foregroundStyle(
                proposal.status == .confirmed ? Color.green :
                (proposal.status == .denied ? Color.red : Color.orange)
            )
            .clipShape(Capsule())
    }
}

/**
 * SuggestPickupSheet
 * 
 * Native Apple MapKit location suggestion sheet.
 */
struct SuggestPickupSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onProposalSubmitted: (Proposal) -> Void

    @State private var locationName: String = "Corner of 10th & Alma"
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
                Section("Proposed Pickup Details") {
                    TextField("Pickup Spot (e.g. Bus Stop, Corner)", text: $locationName)
                    DatePicker("Pickup Time", selection: $pickupDate, displayedComponents: [.hourAndMinute])
                }

                Section("Pickup Location (Apple Maps)") {
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
