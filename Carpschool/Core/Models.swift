import Foundation
import CoreLocation

struct GeoPoint: Codable, Hashable, Sendable {
    var type: String? = "Point"
    var coordinates: [Double]

    init(_ c: CLLocationCoordinate2D) {
        coordinates = [(c.longitude * 1e6).rounded() / 1e6, (c.latitude * 1e6).rounded() / 1e6]
    }
    init(lng: Double, lat: Double) { coordinates = [lng, lat] }

    var coordinate: CLLocationCoordinate2D {
        guard coordinates.count == 2 else { return .init() }
        return .init(latitude: coordinates[1], longitude: coordinates[0])
    }
    var json: [String: Any] { ["type": "Point", "coordinates": coordinates] }
}

struct School: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let schoolCode: String
    let name: String
    let domains: [String]
    let baseUrl: String
    let lastHeartbeat: String?
    enum CodingKeys: String, CodingKey { case id = "_id", schoolCode, name, domains, baseUrl, lastHeartbeat }
}

struct SchoolMeta: Codable, Sendable {
    struct Campus: Codable, Sendable { let coordinates: [Double] }
    struct Limits: Codable, Sendable { let homes: Int; let seats: Int }
    let schoolCode: String
    let name: String
    let campus: Campus
    let limits: Limits
    var campusPoint: GeoPoint { GeoPoint(lng: campus.coordinates[0], lat: campus.coordinates[1]) }
}

struct Car: Codable, Hashable, Sendable { var make: String; var color: String; var plate: String }

enum Role: String, Codable, Sendable { case rider, driver }

struct Me: Codable, Sendable {
    let sub: String
    let verified: Bool?
    let eduEmail: String?
    let role: Role?
    let name: String?
    let phone: String?
    let avatar: String?
    let personalEmail: String?
    let car: Car?
    let licenseConfirmed: Bool?
    let banned: Bool?
}

struct Home: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let label: String
    let location: GeoPoint
    let walkingRadius: Double
    enum CodingKeys: String, CodingKey { case id = "_id", label, location, walkingRadius }
}

enum Direction: String, Codable, CaseIterable, Sendable {
    case toSchool = "to-school"
    case home
    var label: String { self == .toSchool ? "To school" : "Home" }
}

struct Commute: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let homeId: String
    let direction: Direction
    let dates: [String]
    let days: [Int]
    let startTime: String
    let endTime: String
    let status: String
    let createdAt: String?
    enum CodingKeys: String, CodingKey { case id = "_id", homeId, direction, dates, days, startTime, endTime, status, createdAt }
}

struct Passenger: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let rider: String
    let negotiationId: String
    let pickup: GeoPoint
    let time: String
    let status: String
    enum CodingKeys: String, CodingKey { case id = "_id", rider, negotiationId, pickup, time, status }
}

struct Drive: Codable, Identifiable, Hashable, Sendable {
    struct Route: Codable, Hashable, Sendable { let coordinates: [[Double]] }
    let id: String
    let homeId: String
    let direction: Direction
    let dates: [String]
    let days: [Int]
    let startTime: String
    let endTime: String
    let status: String
    let route: Route?
    let seats: Int
    let availableSeats: Int
    let owner: String
    let passengers: [Passenger]
    enum CodingKeys: String, CodingKey { case id = "_id", homeId, direction, dates, days, startTime, endTime, status, route, seats, availableSeats, owner, passengers }

    var routeCoordinates: [CLLocationCoordinate2D] {
        (route?.coordinates ?? []).compactMap { $0.count == 2 ? .init(latitude: $0[1], longitude: $0[0]) : nil }
    }
}

struct Match: Codable, Identifiable, Hashable, Sendable {
    let requestId: String
    let rider: String
    let distanceMeters: Double
    let startTime: String
    let endTime: String
    var id: String { requestId }
}

struct RiderOffer: Codable, Identifiable, Hashable, Sendable {
    let negotiationId: String
    let driveId: String
    let requestId: String
    var id: String { negotiationId }
}

struct Negotiation: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let driver: String
    let rider: String
    let driveId: String
    let requestId: String
    let status: String
    let createdAt: String?
    let updatedAt: String?
    enum CodingKeys: String, CodingKey { case id = "_id", driver, rider, driveId, requestId, status, createdAt, updatedAt }
}

struct ChatMessage: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let negotiationId: String
    let author: String
    let text: String
    let createdAt: String
    enum CodingKeys: String, CodingKey { case id = "_id", negotiationId, author, text, createdAt }
}

struct Proposal: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let negotiationId: String
    let author: String
    let pickup: GeoPoint
    let time: String
    let status: String
    let createdAt: String
    enum CodingKeys: String, CodingKey { case id = "_id", negotiationId, author, pickup, time, status, createdAt }
}

struct Block: Codable, Hashable, Sendable {
    let subject: String
}

struct AcceptResult: Codable, Sendable { let driveId: String; let negotiationId: String?; let pin: String? }
struct PinResult: Codable, Sendable { let pin: String }
struct IdOnly: Codable, Sendable {
    let id: String
    enum CodingKeys: String, CodingKey { case id = "_id" }
}
