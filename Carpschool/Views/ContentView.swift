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
        VStack(spacing: 16) {
            Text("Carpschool")
                .font(.largeTitle.bold())

            Text("Autonomous campus carpooling.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button("Sign in") {
                showAuthSheet = true
            }
            .buttonStyle(.borderedProminent)

            #if DEBUG
            HStack(spacing: 16) {
                Button("Demo Driver") {
                    enterDemoMode(role: .driver)
                }
                Text("•")
                    .foregroundStyle(.tertiary)
                Button("Demo Rider") {
                    enterDemoMode(role: .rider)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.top, 8)
            #endif
        }
        .sheet(isPresented: $showAuthSheet) {
            AuthView()
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
