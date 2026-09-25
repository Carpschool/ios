import SwiftUI
import ClerkKit
import ClerkKitUI

/**
 * ContentView
 * 
 * Root view routing between:
 * 1. Clerk Authentication (native AuthView or Simulator Quickstart)
 * 2. 4-Step Onboarding Flow (if school or role not configured)
 * 3. Role-Adapted Native TabView (Driver Console vs. Rider Portal)
 */
struct ContentView: View {
    @Environment(Clerk.self) private var clerk
    @Environment(AppState.self) private var appState
    
    @State private var showAuthSheet: Bool = false
    @State private var selectedTab: Int = 0

    var body: some View {
        Group {
            if clerk.user == nil && !appState.isDevMockAuth {
                signedOutView
            } else if !appState.isOnboarded || appState.currentSchool == nil {
                OnboardingView()
            } else {
                mainTabView
            }
        }
        .prefetchClerkImages()
    }

    // MARK: - Signed Out View (Clerk Native Authentication)
    
    private var signedOutView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 24) {
                // Carpschool Native Logo & Title
                VStack(spacing: 12) {
                    Image(systemName: "car.2.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(Color.accentColor)

                    Text("Carpschool")
                        .font(.system(size: 32, weight: .black, design: .rounded))

                    Text("Autonomous Federated Campus Carpooling")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .padding(.top, 24)

                // Trust & Architecture Feature List
                VStack(alignment: .leading, spacing: 14) {
                    featureItem(
                        "building.columns.fill",
                        "Autonomous Campus Nodes",
                        "Universities run independent, self-governed servers."
                    )
                    featureItem(
                        "envelope.badge.shield.half.filled",
                        "Zero Central Emails",
                        "Accounts and authentication are managed strictly by Clerk."
                    )
                    featureItem(
                        "location.slash.fill",
                        "Discrete Location",
                        "Single GPS snapshot at boarding and arrival. No background tracking."
                    )
                    featureItem(
                        "heart.fill",
                        "Reciprocal Carpools",
                        "Shared student rides with zero fares and zero payments."
                    )
                }
                .padding(16)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 20)

                Spacer(minLength: 16)

                // Clerk Authentication Buttons
                VStack(spacing: 12) {
                    Button {
                        showAuthSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "lock.shield.fill")
                            Text("Sign In with Clerk")
                        }
                        .frame(maxWidth: .infinity)
                        .bold()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    // Quick Simulator Demo Mode
                    HStack(spacing: 12) {
                        Button {
                            enterDemoMode(role: .driver)
                        } label: {
                            Text("Demo as Driver")
                                .font(.caption.bold())
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(.secondary)

                        Button {
                            enterDemoMode(role: .rider)
                        } label: {
                            Text("Demo as Rider")
                                .font(.caption.bold())
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(.secondary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity)
        }
        .sheet(isPresented: $showAuthSheet) {
            NavigationStack {
                AuthView()
                    .navigationTitle("Sign In")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { showAuthSheet = false }
                        }
                    }
            }
        }
    }

    private func featureItem(_ icon: String, _ title: String, _ desc: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(Color.accentColor)
                .frame(width: 24)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.bold())
                Text(desc)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func enterDemoMode(role: UserRole) {
        appState.isDevMockAuth = true
        appState.currentUserProfile = UserProfile(
            clerkUserId: "demo_student_01",
            primaryEmail: "student@ubc.ca",
            role: role,
            isOnboarded: false,
            isEduVerified: true,
            personalEmail: "student@gmail.com",
            vehicle: VehicleInfo(
                make: "Tesla",
                model: "Model Y",
                color: "Midnight Blue",
                licensePlate: "BC 789-UBC",
                seatCapacity: 3
            ),
            primaryHome: UserHome(
                _id: "home_ubc",
                label: "Campus Residence",
                address: "2329 West Mall, Vancouver, BC",
                walkingRadiusMeters: 75,
                location: GeoLocation(latitude: 49.2606, longitude: -123.2460)
            )
        )
    }

    // MARK: - Main Role-Adapted Tab View
    
    private var mainTabView: some View {
        TabView(selection: $selectedTab) {
            if appState.activeRole == .driver {
                // Driver Console Tabs
                NavigationStack {
                    CorridorMatchingView()
                }
                .tabItem {
                    Label("Corridor", systemImage: "point.topleft.down.to.point.bottomright.curvepath.fill")
                }
                .tag(0)

                NavigationStack {
                    HomesView()
                }
                .tabItem {
                    Label("Homes", systemImage: "house.fill")
                }
                .tag(1)

                NavigationStack {
                    BoardingPINView()
                }
                .tabItem {
                    Label("Boarding", systemImage: "checkmark.shield.fill")
                }
                .tag(2)

                NavigationStack {
                    NegotiationListView()
                }
                .tabItem {
                    Label("Messages", systemImage: "bubble.left.and.bubble.right.fill")
                }
                .tag(3)

                NavigationStack {
                    ProfileView()
                }
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle.fill")
                }
                .tag(4)

            } else {
                // Rider Portal Tabs
                NavigationStack {
                    RiderApplicationsView()
                }
                .tabItem {
                    Label("My Rides", systemImage: "car.side.fill")
                }
                .tag(0)

                NavigationStack {
                    HomesView()
                }
                .tabItem {
                    Label("Homes", systemImage: "house.fill")
                }
                .tag(1)

                NavigationStack {
                    BoardingPINView()
                }
                .tabItem {
                    Label("Boarding PIN", systemImage: "shield.checkered")
                }
                .tag(2)

                NavigationStack {
                    NegotiationListView()
                }
                .tabItem {
                    Label("Messages", systemImage: "bubble.left.and.bubble.right.fill")
                }
                .tag(3)

                NavigationStack {
                    ProfileView()
                }
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle.fill")
                }
                .tag(4)
            }
        }
    }
}
