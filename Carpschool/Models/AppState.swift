import Foundation
import SwiftUI
import Observation

/**
 * AppState
 * 
 * Global observable application state for Carpschool iOS.
 * Utilizes the modern Swift Observation framework (@Observable).
 */
@Observable
class AppState {
    static let shared = AppState()
    
    // School Federation State
    var currentSchool: School?
    var federationTicket: FederationTicket?
    var schoolMeta: SchoolMeta?
    
    // User Identity & Onboarding State
    var currentUserProfile: UserProfile?
    var activeRole: UserRole?
    var isOnboarded: Bool = false
    
    // UI Navigation State
    var selectedTab: Int = 0
    var isPresentingOnboarding: Bool = false
    
    // Mock / Offline Development Helper
    var isDevMockAuth: Bool = false
    var mockClerkUserId: String = "user_ios_mock_001"
    
    init() {
        loadPersistedState()
    }
    
    // MARK: - Persistence & Setup
    
    func loadPersistedState() {
        let defaults = UserDefaults.standard
        if let schoolData = defaults.data(forKey: "saved_current_school"),
           let school = try? JSONDecoder().decode(School.self, from: schoolData) {
            self.currentSchool = school
        }
        
        if let ticketData = defaults.data(forKey: "saved_federation_ticket"),
           let ticket = try? JSONDecoder().decode(FederationTicket.self, from: ticketData) {
            self.federationTicket = ticket
            NetworkService.shared.currentTicket = ticket.ticket
            if let url = self.currentSchool?.baseUrl {
                NetworkService.shared.currentSchoolBaseUrl = url
            }
        }
        
        if let roleString = defaults.string(forKey: "saved_active_role"),
           let role = UserRole(rawValue: roleString) {
            self.activeRole = role
        }
        
        self.isOnboarded = defaults.bool(forKey: "saved_is_onboarded")
    }
    
    func persistState() {
        let defaults = UserDefaults.standard
        if let school = currentSchool,
           let schoolData = try? JSONEncoder().encode(school) {
            defaults.set(schoolData, forKey: "saved_current_school")
        }
        
        if let ticket = federationTicket,
           let ticketData = try? JSONEncoder().encode(ticket) {
            defaults.set(ticketData, forKey: "saved_federation_ticket")
        }
        
        if let role = activeRole {
            defaults.set(role.rawValue, forKey: "saved_active_role")
        }
        
        defaults.set(isOnboarded, forKey: "saved_is_onboarded")
    }
    
    func setSchool(_ school: School, ticket: FederationTicket) {
        self.currentSchool = school
        self.federationTicket = ticket
        NetworkService.shared.currentSchoolBaseUrl = school.baseUrl
        NetworkService.shared.currentTicket = ticket.ticket
        persistState()
    }
    
    func completeOnboarding(role: UserRole, vehicle: VehicleInfo?, primaryHome: UserHome?, personalEmail: String?) {
        self.activeRole = role
        self.isOnboarded = true
        
        if currentUserProfile == nil {
            currentUserProfile = UserProfile(
                clerkUserId: mockClerkUserId,
                primaryEmail: personalEmail ?? "student@university.edu",
                role: role,
                isOnboarded: true,
                isEduVerified: true,
                personalEmail: personalEmail,
                vehicle: vehicle,
                primaryHome: primaryHome
            )
        } else {
            currentUserProfile?.role = role
            currentUserProfile?.isOnboarded = true
            currentUserProfile?.vehicle = vehicle
            currentUserProfile?.primaryHome = primaryHome
            currentUserProfile?.personalEmail = personalEmail
        }
        
        persistState()
    }
    
    func reset() {
        currentSchool = nil
        federationTicket = nil
        currentUserProfile = nil
        activeRole = nil
        isOnboarded = false
        
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "saved_current_school")
        defaults.removeObject(forKey: "saved_federation_ticket")
        defaults.removeObject(forKey: "saved_active_role")
        defaults.removeObject(forKey: "saved_is_onboarded")
    }
}
