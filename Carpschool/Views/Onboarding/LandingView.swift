import SwiftUI
import ClerkKitUI

struct LandingView: View {
    @State private var showAuth = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            Image("Mark")
                .resizable()
                .scaledToFit()
                .frame(width: 96, height: 96)
                .clipShape(.rect(cornerRadius: 22))
                .shadow(color: .brand.opacity(0.25), radius: 18, y: 8)
                .accessibilityHidden(true)
            Text("Carpschool")
                .font(.largeTitle.bold())
                .padding(.top, 24)
            Text("Share rides to school with verified students from your campus.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
                .padding(.horizontal, 32)
            Spacer()
            VStack(alignment: .leading, spacing: 18) {
                Feature(icon: "checkmark.seal.fill", title: "Students only", text: "Everyone verifies a school email.")
                Feature(icon: "map.fill", title: "Matched to your route", text: "Riders a short walk from where you drive.")
                Feature(icon: "lock.fill", title: "PIN at pickup", text: "No live tracking. One snapshot when you board.")
            }
            .padding(.horizontal, 32)
            Spacer()
            Button {
                showAuth = true
            } label: {
                Text("Get Started").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
        }
        .sheet(isPresented: $showAuth) { AuthView() }
    }
}

private struct Feature: View {
    let icon: String, title: String, text: String
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.brand)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(text).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
