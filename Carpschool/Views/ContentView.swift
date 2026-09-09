import SwiftUI

struct ContentView: View {
    @State private var selectedSchool: School?
    @State private var isConnected = false

    var body: some View {
        Group {
            if !isConnected {
                SchoolSelectView(onSchoolConnected: { school in
                    selectedSchool = school
                    isConnected = true
                })
            } else {
                TabView {
                    NavigationStack {
                        HomesView()
                    }
                    .tabItem {
                        Label("Homes", systemImage: "house.fill")
                    }

                    NavigationStack {
                        CorridorMatchingView()
                    }
                    .tabItem {
                        Label("Corridor", systemImage: "point.topleft.down.to.point.bottomright.curvepath.fill")
                    }

                    NavigationStack {
                        BoardingPINView()
                    }
                    .tabItem {
                        Label("Boarding", systemImage: "checkmark.shield.fill")
                    }
                }
            }
        }
    }
}
