import SwiftUI
import ClerkKit

struct RoleSetupView: View {
    @Environment(AppModel.self) private var model
    @Environment(Clerk.self) private var clerk
    @State private var role: Role?
    @State private var name = ""
    @State private var phone = ""
    @State private var personalEmail = ""
    @State private var make = ""
    @State private var color = ""
    @State private var plate = ""
    @State private var license = false
    @State private var confirmLock = false
    @State private var busy = false
    @State private var error: String?

    private var valid: Bool {
        guard let role, name.trimmingCharacters(in: .whitespaces).count >= 2, phone.filter(\.isNumber).count >= 7 else { return false }
        if role == .rider { return true }
        return personalEmail.contains("@") && !make.isEmpty && !color.isEmpty && plate.count >= 2 && license
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("This can't be changed later. Pick the one you'll use all year.")
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                }
                Section("I want to") {
                    RoleRow(title: "Ride", subtitle: "Get picked up near home", icon: "figure.walk", selected: role == .rider) { role = .rider }
                    RoleRow(title: "Drive", subtitle: "Offer seats on my commute", icon: "car.fill", selected: role == .driver) { role = .driver }
                }
                if role != nil {
                    Section {
                        TextField("Full name", text: $name).textContentType(.name)
                        TextField("Phone", text: $phone).textContentType(.telephoneNumber).keyboardType(.phonePad)
                    } header: { Text("About you") } footer: {
                        Text("Your photo comes from your account. Change it in Settings.")
                    }
                }
                if role == .driver {
                    Section("Contact") {
                        TextField("Personal email", text: $personalEmail)
                            .textContentType(.emailAddress).keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                    }
                    Section("Car") {
                        TextField("Make and model", text: $make)
                        TextField("Color", text: $color)
                        TextField("Plate", text: $plate).textInputAutocapitalization(.characters).autocorrectionDisabled()
                    }
                    Section {
                        Toggle("I have a valid driver's license", isOn: $license)
                    } footer: { Text("You'll choose how many seats to offer on each drive.") }
                }
                if let error { Section { Label(error, systemImage: "exclamationmark.circle").foregroundStyle(.red) } }
                Section {
                    Button { confirmLock = true } label: {
                        HStack { Spacer(); if busy { ProgressView() } else { Text("Continue").bold() }; Spacer() }
                    }
                    .disabled(!valid || busy)
                }
            }
            .navigationTitle("Set Up Profile")
            .animation(.default, value: role)
            .onAppear {
                if name.isEmpty, let u = clerk.user { name = [u.firstName, u.lastName].compactMap { $0 }.joined(separator: " ") }
            }
            .confirmationDialog("Continue as a \(role == .driver ? "driver" : "rider")?", isPresented: $confirmLock, titleVisibility: .visible) {
                Button("Continue as \(role == .driver ? "Driver" : "Rider")") { Task { await save() } }
            } message: { Text("Your role is locked once you continue.") }
        }
    }

    private func save() async {
        guard let role else { return }
        busy = true; error = nil
        defer { busy = false }
        var body: [String: Any] = ["role": role.rawValue, "name": name.trimmingCharacters(in: .whitespaces), "phone": phone.trimmingCharacters(in: .whitespaces)]
        if role == .driver {
            body["personalEmail"] = personalEmail.trimmingCharacters(in: .whitespaces).lowercased()
            body["car"] = ["make": make.trimmingCharacters(in: .whitespaces), "color": color.trimmingCharacters(in: .whitespaces), "plate": plate.uppercased().trimmingCharacters(in: .whitespaces)]
            body["licenseConfirmed"] = true
        }
        do {
            try await model.send("/profile", body: body)
            await model.refreshMe()
        } catch { self.error = error.localizedDescription }
    }
}

private struct RoleRow: View {
    let title: String, subtitle: String, icon: String, selected: Bool, action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon).font(.title2).frame(width: 36).foregroundStyle(.brand)
                VStack(alignment: .leading) {
                    Text(title).font(.headline).foregroundStyle(.primary)
                    Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(selected ? Color.brand : Color.secondary.opacity(0.4))
                    .contentTransition(.symbolEffect(.replace))
            }
            .padding(.vertical, 4)
        }
        .sensoryFeedback(.selection, trigger: selected)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
