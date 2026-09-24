import Foundation

// MARK: - Carpool Ride Models

/**
 * PassengerEntry
 * 
 * Verified passenger status on a confirmed carpool ride.
 */
struct PassengerEntry: Codable, Hashable {
    let riderId: String
    let boardingPin: String?
    let isBoarded: Bool?
    let boardedAt: String?
}

/**
 * Carpool
 * 
 * Scheduled reciprocal ride matching driver and onboarded passengers.
 */
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
