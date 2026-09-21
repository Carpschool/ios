import SwiftUI
import ClerkKit
import ClerkKitUI

/**
 * CarpschoolApp
 * 
 * Native iOS application entry point for Carpschool.
 * Targets iOS 17.0+ using modern SwiftUI and Observation framework.
 * Configured with official Clerk iOS SDK and native Apple MapKit.
 */
@main
struct CarpschoolApp: App {
    @State private var appState = AppState.shared
    
    init() {
        // Configure official Clerk iOS SDK
        Clerk.configure(publishableKey: "pk_test_ZGVmaW5pdGUtZmF3bi03OC5jbGVyay5hY2NvdW50cy5kZXYk")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(Clerk.shared)
                .environment(appState)
        }
    }
}
