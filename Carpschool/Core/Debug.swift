#if DEBUG
import Foundation
import ClerkKit

/// Simulator test hooks driven by launch environment (SIMCTL_CHILD_CS_*). Compiled out of release builds.
@MainActor
enum DebugHooks {
    static var env: [String: String] { ProcessInfo.processInfo.environment }

    static func autoSignIn() async {
        guard let email = env["CS_EMAIL"], let password = env["CS_PASSWORD"] else { return }
        if let current = Clerk.shared.user, current.primaryEmailAddress?.emailAddress == email { return }
        if Clerk.shared.user != nil { try? await Clerk.shared.auth.signOut() }
        do {
            var s = try await Clerk.shared.auth.signInWithPassword(identifier: email, password: password)
            if s.status == .needsSecondFactor {
                s = try await s.sendMfaEmailCode()
                s = try await s.verifyMfaCode(env["CS_CODE"] ?? "424242", type: .emailCode)
            } else if s.status == .needsFirstFactor {
                s = try await s.sendEmailCode()
                s = try await s.verifyCode(env["CS_CODE"] ?? "424242")
            }
            print("[debug] sign-in status", s.status)
        } catch {
            print("[debug] sign-in failed", error)
        }
    }

    static func route(_ router: Router) {
        guard let r = env["CS_ROUTE"] else { return }
        let parts = r.split(separator: ":", maxSplits: 1).map(String.init)
        switch parts[0] {
        case "rides": router.tab = .rides
        case "chats": router.tab = .chats
        case "settings": router.tab = .settings
        case "homes": router.home.append(Route.homes)
        case "newRequest": router.home.append(Route.newRequest)
        case "newDrive": router.home.append(Route.newDrive)
        case "blocked": router.tab = .settings; router.settings.append(Route.blocked)
        case "drive" where parts.count == 2: router.home.append(Route.drive(parts[1]))
        case "chat" where parts.count == 2: router.open(.chat(parts[1]))
        case "ride" where parts.count == 2: router.open(.ride(parts[1]))
        default: break
        }
    }
}
#endif
