import Foundation
import CoreLocation

// MARK: - School Models

struct School: Identifiable, Codable, Hashable {
    var id: String { schoolCode }
    let schoolCode: String
    let officialName: String
    let allowedEmailDomains: [String]
    let baseUrl: String
    let isTrusted: Bool
    var logoUrl: String?
}

struct SchoolMeta: Codable {
    let schoolCode: String
    let officialName: String
    let allowedEmailDomains: [String]
    let centralAuthorityPublicKey: String?
    let schoolPublicKey: String?
    let requireEduVerificationForRiders: Bool?
    let requireEduVerificationForDrivers: Bool?
}

struct FederationTicket: Codable {
    let ticket: String
    let schoolBaseUrl: String
    let isTrusted: Bool
    let expiresAt: String
}

// MARK: - User & Role Models

enum UserRole: String, Codable, CaseIterable {
    case rider = "rider"
    case driver = "driver"
    
    var title: String {
        switch self {
        case .rider: return "Student Rider"
        case .driver: return "Student Driver"
        }
    }
    
    var description: String {
        switch self {
        case .rider: return "Looking for reliable carpools to & from campus."
        case .driver: return "Driving my own car and willing to share empty seats."
        }
    }
    
    var iconName: String {
        switch self {
        case .rider: return "person.crop.circle.badge.plus"
        case .driver: return "car.fill"
        }
    }
}

struct VehicleInfo: Codable, Hashable {
    var make: String
    var model: String
    var color: String
    var licensePlate: String
    var seatCapacity: Int
}

struct UserProfile: Codable, Identifiable {
    var id: String { clerkUserId }
    let clerkUserId: String
    var primaryEmail: String?
    var role: UserRole?
    var isOnboarded: Bool
    var isEduVerified: Bool
    var eduEmail: String?
    var personalEmail: String?
    var vehicle: VehicleInfo?
    var primaryHome: UserHome?
}

// MARK: - Location & Home Models

struct GeoLocation: Codable, Hashable {
    let type: String
    let coordinates: [Double] // [longitude, latitude]
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: coordinates.count > 1 ? coordinates[1] : 0,
            longitude: coordinates.count > 0 ? coordinates[0] : 0
        )
    }
    
    init(latitude: Double, longitude: Double) {
        self.type = "Point"
        self.coordinates = [longitude, latitude]
    }
}

struct UserHome: Identifiable, Codable, Hashable {
    var id: String { _id ?? UUID().uuidString }
    let _id: String?
    var label: String
    var address: String
    var walkingRadiusMeters: Int // 10m to 200m
    var location: GeoLocation
    
    var coordinate: CLLocationCoordinate2D {
        location.coordinate
    }
}

// MARK: - Commute Directions & Schedules

enum CommuteDirection: String, Codable, CaseIterable {
    case homeToSchool = "HOME_TO_SCHOOL"
    case schoolToHome = "SCHOOL_TO_HOME"
    
    var displayName: String {
        switch self {
        case .homeToSchool: return "Home → School"
        case .schoolToHome: return "School → Home"
        }
    }
    
    var iconName: String {
        switch self {
        case .homeToSchool: return "arrow.up.right"
        case .schoolToHome: return "arrow.down.left"
        }
    }
}

enum ScheduleType: String, Codable, CaseIterable {
    case oneTime = "ONE_TIME"
    case recurring = "RECURRING"
    
    var displayName: String {
        switch self {
        case .oneTime: return "One-Time Commute"
        case .recurring: return "Recurring Daily"
        }
    }
}

// MARK: - Rider Applications

struct RiderApplication: Identifiable, Codable, Hashable {
    var id: String { _id }
    let _id: String
    let riderId: String?
    let direction: CommuteDirection
    let scheduleType: ScheduleType
    let targetTime: String
    let walkingRadiusMeters: Int
    let pickupHome: UserHome?
    let status: String?
    let notes: String?
}

// MARK: - Negotiation & Proposals

enum ProposalStatus: String, Codable {
    case pending = "PENDING"
    case confirmed = "CONFIRMED"
    case denied = "DENIED"
    case superseded = "SUPERSEDED"
    
    var badgeColor: String {
        switch self {
        case .pending: return "orange"
        case .confirmed: return "green"
        case .denied: return "red"
        case .superseded: return "gray"
        }
    }
}

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

struct ChatMessage: Identifiable, Codable, Hashable {
    var id: String { _id ?? UUID().uuidString }
    let _id: String?
    let senderId: String
    let senderName: String?
    let message: String
    let timestamp: String
    let isSystem: Bool?
}

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

// MARK: - Carpool Ride Models

struct PassengerEntry: Codable, Hashable {
    let riderId: String
    let boardingPin: String?
    let isBoarded: Bool?
    let boardedAt: String?
}

struct Carpool: Identifiable, Codable, Hashable {
    var id: String { _id }
    let _id: String
    let driverId: String
    let direction: CommuteDirection
    let targetDate: String
    let status: String
    let passengers: [PassengerEntry]?
    let availableSeats: Int
}
