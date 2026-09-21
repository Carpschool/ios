import SwiftUI
import ClerkKit
import ClerkKitUI

/**
 * ProfileView
 * 
 * Displays the verified student profile, vehicle specifications (for drivers),
 * connected school server status, and Clerk account actions.
 */
struct ProfileView: View {
    @Environment(AppState.self) private var appState
    @Environment(Clerk.self) private var clerk
    
    @State private var showSignOutConfirmation: Bool = false

    var body: some View {
        List {
            // User Header & Role Badge
            Section {
                HStack(spacing: 16) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 54))
                        .foregroundStyle(Color.accentColor)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(clerk.user?.id ?? "Verified Student")
                            .font(.headline)
                        
                        if let email = clerk.user?.primaryEmailAddress?.emailAddress ?? appState.currentUserProfile?.primaryEmail {
                            Text(email)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        // Role Badge
                        HStack(spacing: 4) {
                            Image(systemName: appState.activeRole == .driver ? "car.fill" : "person.crop.circle.badge.plus")
                                .font(.caption2)
                            Text(appState.activeRole?.title ?? "Member")
                                .font(.caption2.bold())
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(appState.activeRole == .driver ? Color.indigo.opacity(0.15) : Color.blue.opacity(0.15))
                        .foregroundStyle(appState.activeRole == .driver ? Color.indigo : Color.blue)
                        .clipShape(Capsule())
                    }
                }
                .padding(.vertical, 4)
            }

            // Driver Vehicle Information (if Driver)
            if appState.activeRole == .driver {
                Section("Vehicle Information") {
                    if let v = appState.currentUserProfile?.vehicle {
                        LabeledContent("Vehicle", value: "\(v.color) \(v.make) \(v.model)")
                        LabeledContent("Car License Plate", value: v.licensePlate)
                        LabeledContent("Seat Capacity", value: "\(v.seatCapacity) passengers")
                    } else {
                        LabeledContent("Vehicle", value: "Midnight Blue Tesla Model Y")
                        LabeledContent("Car License Plate", value: "BC 789-UBC")
                        LabeledContent("Seat Capacity", value: "3 passengers")
                    }
                }
            }

            // Primary Residence & Walking Radius
            Section("Primary Residence") {
                if let home = appState.currentUserProfile?.primaryHome {
                    LabeledContent("Label", value: home.label)
                    LabeledContent("Address", value: home.address)
                    LabeledContent("Walking Radius", value: "\(home.walkingRadiusMeters) meters")
                } else {
                    LabeledContent("Residence", value: "2329 West Mall, Vancouver")
                    LabeledContent("Walking Radius", value: "75 meters")
                }
            }

            // Connected School Server
            Section("Connected Campus Server") {
                if let school = appState.currentSchool {
                    LabeledContent("University", value: school.officialName)
                    LabeledContent("Node URL", value: school.baseUrl)
                    HStack {
                        Text("Status")
                        Spacer()
                        Label(school.isTrusted ? "Verified Directory" : "Self-Hosted Node", systemImage: school.isTrusted ? "checkmark.seal.fill" : "network")
                            .font(.caption.bold())
                            .foregroundStyle(school.isTrusted ? .green : .orange)
                    }
                }
            }

            // Federation Policies & Privacy
            Section("Federation & Privacy") {
                Label("Zero Outbound Emails from Central", systemImage: "envelope.badge.shield.half.filled")
                    .font(.caption)
                Label("Single Discrete GPS Read (No Tracking)", systemImage: "location.slash.fill")
                    .font(.caption)
                Label("100% Reciprocal (Zero Payments)", systemImage: "heart.fill")
                    .font(.caption)
            }

            // Account & Sign Out
            Section {
                Button(role: .destructive) {
                    showSignOutConfirmation = true
                } label: {
                    HStack {
                        Spacer()
                        Text("Sign Out & Disconnect")
                        Spacer()
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Profile & Settings")
        .confirmationDialog("Are you sure you want to sign out?", isPresented: $showSignOutConfirmation, titleVisibility: .visible) {
            Button("Sign Out", role: .destructive) {
                Task {
                    try? await clerk.auth.signOut()
                    appState.reset()
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}
