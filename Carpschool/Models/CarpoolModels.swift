import Foundation
import CoreLocation

// MARK: - School Models

struct School: Identifiable, Codable {
    var id: String { schoolCode }
    let schoolCode: String
    let officialName: String
    let allowedEmailDomains: [String]
    let baseUrl: String
    let isTrusted: Bool
}

struct FederationTicket: Codable {
    let ticket: String
    let schoolBaseUrl: String
    let isTrusted: Bool
    let expiresAt: String
}

// MARK: - User & Home Models

struct UserHome: Identifiable, Codable {
    var id: String { _id ?? UUID().uuidString }
    let _id: String?
    let label: String
    let address: String
    let walkingRadiusMeters: Int // 10m to 200m
    let location: GeoLocation
}

struct GeoLocation: Codable {
    let type: String
    let coordinates: [Double] // [longitude, latitude]
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: coordinates[1], longitude: coordinates[0])
    }
}

// MARK: - Rider Applications

enum CommuteDirection: String, Codable, CaseIterable {
    case homeToSchool = "HOME_TO_SCHOOL"
    case schoolToHome = "SCHOOL_TO_HOME"
}

enum ScheduleType: String, Codable {
    case oneTime = "ONE_TIME"
    case recurring = "RECURRING"
}

struct RiderApplication: Identifiable, Codable {
    var id: String { _id }
    let _id: String
    let direction: CommuteDirection
    let scheduleType: ScheduleType
    let targetTime: String
    let walkingRadiusMeters: Int
    let notes: String?
}

// MARK: - Negotiation & Proposal Models

enum ProposalStatus: String, Codable {
    case pending = "PENDING"
    case confirmed = "CONFIRMED"
    case denied = "DENIED"
    case superseded = "SUPERSEDED"
}

struct Proposal: Identifiable, Codable {
    var id: String { proposalId }
    let proposalId: String
    let pickupPointName: String
    let pickupCoordinates: [Double]
    let proposedTime: String
    let status: ProposalStatus
}

struct Negotiation: Identifiable, Codable {
    var id: String { _id }
    let _id: String
    let direction: CommuteDirection
    let status: String
    let proposals: [Proposal]
}

// MARK: - Carpool Models

struct Carpool: Identifiable, Codable {
    var id: String { _id }
    let _id: String
    let direction: CommuteDirection
    let targetDate: String
    let status: String
    let availableSeats: Int
}
