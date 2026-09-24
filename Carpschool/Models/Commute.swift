import Foundation

// MARK: - Commute Directions & Schedules

/**
 * CommuteDirection
 * 
 * Commute path: Home to School or School to Home.
 */
enum CommuteDirection: String, Codable, CaseIterable {
    case homeToSchool = "HOME_TO_SCHOOL"
    case schoolToHome = "SCHOOL_TO_HOME"
    
    var displayName: String {
        switch self {
        case .homeToSchool: return "Home to campus"
        case .schoolToHome: return "Campus to home"
        }
    }
    
    var iconName: String {
        switch self {
        case .homeToSchool: return "arrow.up.right"
        case .schoolToHome: return "arrow.down.left"
        }
    }
}

/**
 * ScheduleType
 * 
 * One-time ride or recurring daily commute.
 */
enum ScheduleType: String, Codable, CaseIterable {
    case oneTime = "ONE_TIME"
    case recurring = "RECURRING"
    
    var displayName: String {
        switch self {
        case .oneTime: return "One-time"
        case .recurring: return "Recurring daily"
        }
    }
}

/**
 * RiderApplication
 * 
 * Ride request posted by a student rider.
 */
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
