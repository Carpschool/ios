import Foundation
import SwiftUI

enum AppConfig {
    static let clerkPublishableKey = (Bundle.main.object(forInfoDictionaryKey: "ClerkPublishableKey") as? String) ?? ""

    /// Central URL comes from Info.plist (CENTRAL_URL build setting) and can be overridden in Settings.
    static var defaultCentralURL: String {
        (Bundle.main.object(forInfoDictionaryKey: "CentralURL") as? String) ?? ""
    }

    static var centralURL: String {
        get {
            let o = UserDefaults.standard.string(forKey: "centralOverride") ?? ""
            return o.isEmpty ? defaultCentralURL : o
        }
        set { UserDefaults.standard.set(newValue, forKey: "centralOverride") }
    }
}

extension Color {
    static let brand = Color("Brand")
    static let highlight = Color("Highlight")
}

extension ShapeStyle where Self == Color {
    static var brand: Color { Color("Brand") }
    static var highlight: Color { Color("Highlight") }
}
