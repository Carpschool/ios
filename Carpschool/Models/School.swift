import Foundation

// MARK: - School Models

/**
 * School
 * 
 * Represents an autonomous university or college campus node.
 */
struct School: Identifiable, Codable, Hashable {
    var id: String { schoolCode }
    let schoolCode: String
    let officialName: String
    let allowedEmailDomains: [String]
    let baseUrl: String
    let isTrusted: Bool
    var logoUrl: String?
}

/**
 * SchoolMeta
 * 
 * Cryptographically signed metadata published by each autonomous school server.
 */
struct SchoolMeta: Codable {
    let schoolCode: String
    let officialName: String
    let allowedEmailDomains: [String]
    let centralAuthorityPublicKey: String?
    let schoolPublicKey: String?
    let requireEduVerificationForRiders: Bool?
    let requireEduVerificationForDrivers: Bool?
}

/**
 * FederationTicket
 * 
 * Ed25519-signed ticket issued by Central Server, presented offline to School Server.
 */
struct FederationTicket: Codable {
    let ticket: String
    let schoolBaseUrl: String
    let isTrusted: Bool
    let expiresAt: String
}
