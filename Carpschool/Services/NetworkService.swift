import Foundation

/**
 * NetworkService
 * 
 * Handles REST networking for:
 * 1. Central Server: Listing verified schools, requesting Ed25519 Federation Tickets.
 * 2. School Server: Offline ticket presentation, homes CRUD, matching, in-chat proposals.
 */
class NetworkService {
    static let shared = NetworkService()
    private init() {}

    var centralServerUrl = "http://localhost:4000"
    var currentSchoolBaseUrl = "http://localhost:5000"
    var currentTicket: String?

    // TODO: Implement fetchSchools() from Central Server
    func fetchSchools() async throws -> [School] {
        // TODO: Call GET /api/v1/schools
        return []
    }

    // TODO: Implement requestFederationTicket(schoolCode:customBaseUrl:)
    func requestFederationTicket(schoolCode: String, customBaseUrl: String? = nil) async throws -> FederationTicket {
        // TODO: Call POST /api/v1/schools/ticket with Bearer Clerk Token
        return FederationTicket(ticket: "", schoolBaseUrl: "", isTrusted: true, expiresAt: "")
    }

    // TODO: Implement fetchHomes() from School Server
    func fetchHomes() async throws -> [UserHome] {
        // TODO: Call GET /api/v1/homes with Bearer Federation Ticket
        return []
    }

    // TODO: Implement saveHome(label:address:latitude:longitude:walkingRadiusMeters:)
    func saveHome(label: String, address: String, lat: Double, lng: Double, radius: Int) async throws -> UserHome {
        // TODO: Call POST /api/v1/homes
        return UserHome(_id: nil, label: label, address: address, walkingRadiusMeters: radius, location: GeoLocation(type: "Point", coordinates: [lng, lat]))
    }

    // TODO: Implement submitBoardingPin(carpoolId:riderId:pin:lat:lng:)
    func submitBoardingPin(carpoolId: String, riderId: String, pin: String, lat: Double, lng: Double) async throws -> Bool {
        // TODO: Call POST /api/v1/carpools/:id/board-passenger with single GPS coordinate read
        return true
    }

    // TODO: Implement endRide(carpoolId:lat:lng:)
    func endRide(carpoolId: String, lat: Double, lng: Double) async throws -> Bool {
        // TODO: Call POST /api/v1/carpools/:id/end-ride with single GPS coordinate read
        return true
    }
}
