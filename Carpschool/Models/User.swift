import Foundation

// MARK: - User & Role Models

/**
 * UserRole
 * 
 * Mutually exclusive single role: Student Rider or Student Driver.
 */
enum UserRole: String, Codable, CaseIterable {
    case rider = "rider"
    case driver = "driver"
    
    var title: String {
        switch self {
        case .rider: return "Student Rider"
        case .driver: return "Student Driver"
        }
    }
    
    var subtitle: String {
        switch self {
        case .rider: return "Looking for rides to and from campus."
        case .driver: return "Driving to campus with available seats."
        }
    }
    
    var iconName: String {
        switch self {
        case .rider: return "person.crop.circle.badge.plus"
        case .driver: return "car.fill"
        }
    }
}

/**
 * VehicleInfo
 * 
 * Vehicle specifications mandatory for student drivers.
 */
struct VehicleInfo: Codable, Hashable {
    var make: String
    var model: String
    var color: String
    var licensePlate: String
    var seatCapacity: Int
}

/**
 * UserProfile
 * 
 * Student identity stored on the local school node.
 */
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
