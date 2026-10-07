import SwiftUI
import ClerkKit
import ClerkKitUI

struct RootView: View {
    @Environment(Clerk.self) private var clerk
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @State private var booted = false

    var body: some View {
        Group {
            if !booted {
                ProgressView().controlSize(.large)
            } else if clerk.user == nil {
                LandingView()
            } else if model.school == nil {
                SchoolPickerView()
            } else {
                switch model.meState {
                case .idle, .loading where model.me == nil:
                    ProgressView("Connecting to \(model.school?.name ?? "school")…")
                case .failed(let msg) where model.me == nil:
                    ErrorBanner(message: msg) { Task { await model.refreshMe() } }
                default:
                    if let me = model.me, me.banned == true {
                        ContentUnavailableView("Account suspended", systemImage: "hand.raised", description: Text("Your school has suspended this account. Contact a school admin."))
                    } else if model.me?.verified != true {
                        VerifyEmailView()
                    } else if model.me?.role == nil {
                        RoleSetupView()
                    } else {
                        MainTabView()
                    }
                }
            }
        }
        .animation(.default, value: clerk.user?.id)
        .prefetchClerkImages()
        .task {
            #if DEBUG
            await DebugHooks.autoSignIn()
            #endif
            await model.loadSchools()
            #if DEBUG
            if model.school == nil, let code = DebugHooks.env["CS_SCHOOL"], let s = model.schools?.first(where: { $0.schoolCode == code }) {
                await model.choose(s)
            }
            #endif
            booted = true
            #if DEBUG
            DebugHooks.route(router)
            #endif
        }
        .task(id: "\(clerk.user?.id ?? "")|\(model.school?.schoolCode ?? "")") {
            if clerk.user == nil { model.signedOut() }
            else if model.school != nil { await model.refreshMe() }
        }
    }
}

struct MainTabView: View {
    @Environment(Router.self) private var router
    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.tab) {
            NavigationStack(path: $router.home) { DashboardView().appDestinations() }
                .tabItem { Label("Home", systemImage: "house") }.tag(AppTab.home)
            NavigationStack(path: $router.rides) { RidesView().appDestinations() }
                .tabItem { Label("Rides", systemImage: "ticket") }.tag(AppTab.rides)
            NavigationStack(path: $router.chats) { ChatsView().appDestinations() }
                .tabItem { Label("Chats", systemImage: "bubble.left.and.bubble.right") }.tag(AppTab.chats)
            NavigationStack(path: $router.settings) { SettingsView().appDestinations() }
                .tabItem { Label("Settings", systemImage: "gearshape") }.tag(AppTab.settings)
        }
    }
}
