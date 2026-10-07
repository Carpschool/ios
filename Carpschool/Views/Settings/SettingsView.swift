import SwiftUI
import ClerkKit
import ClerkKitUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(Clerk.self) private var clerk
    @State private var showProfile = false
    @State private var confirmSwitch = false
    @State private var central = AppConfig.centralURL

    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    AsyncImage(url: URL(string: clerk.user?.imageUrl ?? "")) { img in
                        img.resizable().scaledToFill()
                    } placeholder: {
                        InitialsAvatar(id: model.me?.sub ?? "", size: 56)
                    }
                    .frame(width: 56, height: 56)
                    .clipShape(.circle)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(model.me?.name ?? "").font(.title3.weight(.semibold))
                        Text(model.me?.eduEmail ?? "").font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer()
                    StatusBadge(text: model.isDriver ? "Driver" : "Rider", color: .brand)
                }
                .padding(.vertical, 4)
                Button("Manage Account & Photo") { showProfile = true }
            } footer: { Text("Your role is locked. Your photo comes from your account.") }

            Section("Profile") {
                LabeledContent("Phone", value: model.me?.phone ?? "–")
                if model.isDriver, let car = model.me?.car {
                    LabeledContent("Personal email", value: model.me?.personalEmail ?? "–")
                    LabeledContent("Car", value: "\(car.color) \(car.make)")
                    LabeledContent("Plate", value: car.plate)
                }
            }

            Section("Carpooling") {
                NavigationLink(value: Route.homes) { Label("Homes", systemImage: "house") }
                NavigationLink(value: Route.blocked) { Label("Blocked Students", systemImage: "hand.raised") }
            }

            Section {
                LabeledContent("School", value: model.school?.name ?? "")
                Button("Switch School") { confirmSwitch = true }
            } footer: { Text("Switching means verifying again with the new school.") }

            Section {
                TextField("Network URL", text: $central)
                    .textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
                    .onSubmit {
                        AppConfig.centralURL = central == AppConfig.defaultCentralURL ? "" : central
                        Task { await model.loadSchools() }
                    }
            } header: { Text("Advanced") } footer: { Text("The Carpschool network this app trusts. Leave as is unless your school tells you otherwise.") }

            Section {
                Button("Sign Out", role: .destructive) { Task { try? await clerk.auth.signOut(); model.signedOut() } }
            }
        }
        .navigationTitle("Settings")
        .sheet(isPresented: $showProfile) { UserProfileView() }
        .confirmationDialog("Switch school?", isPresented: $confirmSwitch, titleVisibility: .visible) {
            Button("Switch School") { Task { await model.choose(nil) } }
        }
    }
}

struct BlockedView: View {
    @Environment(AppModel.self) private var model
    @State private var blocks: [Block]?
    @State private var error: String?

    var body: some View {
        Group {
            if let blocks {
                if blocks.isEmpty {
                    ContentUnavailableView("Nobody blocked", systemImage: "hand.raised", description: Text("Students you block can't match or chat with you."))
                } else {
                    List(blocks, id: \.subject) { b in
                        HStack(spacing: 12) {
                            InitialsAvatar(id: b.subject, size: 36)
                            Text("Student \(Fmt.shortId(b.subject))")
                            Spacer()
                            Button("Unblock") { Task { await unblock(b) } }.buttonStyle(.bordered).controlSize(.small)
                        }
                    }
                }
            } else if let error {
                ErrorBanner(message: error) { Task { await load() } }
            } else { ProgressView() }
        }
        .navigationTitle("Blocked")
        .task { await load() }
    }

    private func load() async {
        do { blocks = try await model.get([Block].self, "/blocks"); error = nil } catch { self.error = error.localizedDescription }
    }
    private func unblock(_ b: Block) async {
        _ = try? await model.send("/blocks/" + (b.subject.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? b.subject), method: "DELETE")
        model.revision += 1
        await load()
    }
}
