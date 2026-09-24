import Foundation
import CoreLocation

// MARK: - Negotiation & Proposals

/**
 * ProposalStatus
 * 
 * Lifecycle status of an in-chat pickup proposal.
 */
enum ProposalStatus: String, Codable {
    case pending = "PENDING"
    case confirmed = "CONFIRMED"
    case denied = "DENIED"
    case superseded = "SUPERSEDED"
    
    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .confirmed: return "Confirmed"
        case .denied: return "Declined"
        case .superseded: return "Replaced"
        }
    }
}

/**
 * Proposal
 * 
 * Proposed pickup spot and time within rider walking radius.
 */
struct Proposal: Identifiable, Codable, Hashable {
    var id: String { proposalId }
    let proposalId: String
    let pickupPointName: String
    let pickupCoordinates: [Double]
    let proposedTime: String
    let status: ProposalStatus
    let proposedBy: String?
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: pickupCoordinates.count > 1 ? pickupCoordinates[1] : 0,
            longitude: pickupCoordinates.count > 0 ? pickupCoordinates[0] : 0
        )
    }
}

/**
 * ChatMessage
 * 
 * Text message or system event in a carpool negotiation thread.
 */
struct ChatMessage: Identifiable, Codable, Hashable {
    var id: String { _id ?? UUID().uuidString }
    let _id: String?
    let senderId: String
    let senderName: String?
    let message: String
    let timestamp: String
    let isSystem: Bool?
}

/**
 * Negotiation
 * 
 * Active coordination conversation between a student driver and passenger.
 */
struct Negotiation: Identifiable, Codable, Hashable {
    var id: String { _id }
    let _id: String
    let applicationId: String?
    let driverId: String
    let riderId: String
    let direction: CommuteDirection
    let status: String
    let targetDate: String?
    var proposals: [Proposal]
    var messages: [ChatMessage]?
}
