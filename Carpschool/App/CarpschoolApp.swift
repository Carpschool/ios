import SwiftUI
import ClerkKit

@main
struct CarpschoolApp: App {
    @State private var model = AppModel()
    @State private var router = Router()

    init() {
        Clerk.configure(publishableKey: AppConfig.clerkPublishableKey)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(Clerk.shared)
                .environment(model)
                .environment(router)
                .tint(.brand)
        }
    }
}
