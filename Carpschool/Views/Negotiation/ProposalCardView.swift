import SwiftUI
import MapKit

/**
 * ProposalCardView
 * 
 * Interactive pickup proposal card embedded in negotiation chat stream.
 */
struct ProposalCardView: View {
    let proposal: Proposal
    var onConfirm: () -> Void
    var onDeny: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Proposed Pickup Point", systemImage: "mappin.circle.fill")
                    .font(.caption.bold())
                    .foregroundStyle(Color.accentColor)
                Spacer()
                statusBadge
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(proposal.pickupPointName)
                    .font(.headline)
                Text("Proposed time: \(proposal.proposedTime)")
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
                            Text("Decline")
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
        Text(proposal.status.displayName)
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
