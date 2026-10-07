import SwiftUI

enum Route: Hashable {
    case drive(String)
    case chat(String)
    case ride(String)
    case homes
    case newRequest
    case newDrive
    case blocked
}

enum AppTab: Hashable { case home, rides, chats, settings }

@MainActor
@Observable
final class Router {
    var tab: AppTab = .home
    var home = NavigationPath()
    var rides = NavigationPath()
    var chats = NavigationPath()
    var settings = NavigationPath()

    func open(_ r: Route) {
        switch r {
        case .chat:
            tab = .chats; chats = NavigationPath(); chats.append(r)
        case .ride:
            tab = .rides; rides = NavigationPath(); rides.append(r)
        default:
            home.append(r)
        }
    }
}

extension View {
    func appDestinations() -> some View {
        navigationDestination(for: Route.self) { r in
            switch r {
            case .drive(let id): DriveDetailView(id: id)
            case .chat(let id): ChatView(id: id)
            case .ride(let id): RideDetailView(id: id)
            case .homes: HomesView()
            case .newRequest: NewCommuteView(kind: .request)
            case .newDrive: NewCommuteView(kind: .drive)
            case .blocked: BlockedView()
            }
        }
    }
}
