import SwiftUI
import ClerkKit
import ClerkKitUI

/**
 * ProfileView
 * 
 * Displays verified student profile, Clerk UserButton account access,
 * driver vehicle details, connected school server status, and sign out.
 */
struct ProfileView: View {
    @Environment(AppState.self) private var appState
    @Environment(Clerk.self) private var clerk
    
    @State private var showSignOutConfirmation: Bool = false

    var body: some View {
        List {
            // Clerk User Header & UserButton
            Section {
                HStack(spacing: 16) {
                    UserButton()
                        .frame(width: 44, height: 44)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(displayName)
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
                    
                    Spacer()
                }
                .padding(.vertical, 4)
            } footer: {
                Text("Tap your avatar to manage account security, passkeys, and multi-factor authentication with Clerk.")
            }

            // Driver Vehicle Information
            if appState.activeRole == .driver {
                Section("Driver Vehicle") {
                    if let v = appState.currentUserProfile?.vehicle {
                        LabeledContent("Vehicle", value: "\(v.color) \(v.make) \(v.model)")
                        LabeledContent("License Plate", value: v.licensePlate)
                        LabeledContent("Seat Capacity", value: "\(v.seatCapacity) seats")
                    } else {
                        LabeledContent("Vehicle", value: "Midnight Blue Tesla Model Y")
                        LabeledContent("License Plate", value: "BC 789-UBC")
                        LabeledContent("Seat Capacity", value: "3 seats")
                    }
                }
            }

            // Primary Residence & Walking Radius
            Section("Primary Residence") {
                if let home = appState.currentUserProfile?.primaryHome {
                    LabeledContent("Label", value: home.label)
                    LabeledContent("Address", value: home.address)
                    LabeledContent("Walking Radius", value: "\(home.walkingRadiusMeters) m")
                } else {
                    LabeledContent("Residence", value: "2329 West Mall, Vancouver")
                    LabeledContent("Walking Radius", value: "75 m")
                }
            }

            // Connected School Server
            Section("Connected Campus Server") {
                if let school = appState.currentSchool {
                    LabeledContent("Campus", value: school.officialName)
                    LabeledContent("Server URL", value: school.baseUrl)
                    HStack {
                        Text("Status")
                        Spacer()
                        Label(school.isTrusted ? "Verified Campus" : "Self-Hosted Node", systemImage: school.isTrusted ? "checkmark.seal.fill" : "network")
                            .font(.caption.bold())
                            .foregroundStyle(school.isTrusted ? .green : .orange)
                    }
                }
            }

            // Privacy Principles
            Section("Privacy Principles") {
                Label("Zero outbound emails from central server", systemImage: "envelope.badge.shield.half.filled")
                    .font(.caption)
                Label("Single discrete GPS read (no continuous tracking)", systemImage: "location.slash.fill")
                    .font(.caption)
                Label("100% reciprocal student carpools (zero fares)", systemImage: "heart.fill")
                    .font(.caption)
            }

            // Account Sign Out
            Section {
                Button(role: .destructive) {
                    showSignOutConfirmation = true
                } label: {
                    HStack {
                        Spacer()
                        Text("Sign Out")
                        Spacer()
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Profile")
        .confirmationDialog("Sign out of your Carpschool account?", isPresented: $showSignOutConfirmation, titleVisibility: .visible) {
            Button("Sign Out", role: .destructive) {
                Task {
                    try? await clerk.auth.signOut()
                    appState.reset()
                }
            }
        }
    }

    private var displayName: String {
        let name = [clerk.user?.firstName, clerk.user?.lastName]
            .compactMap { $0 }
            .joined(separator: " ")
        if !name.isEmpty {
            return name
        }
        return clerk.user?.primaryEmailAddress?.emailAddress ?? clerk.user?.id ?? "Verified Student"
    }
}
