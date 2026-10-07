import SwiftUI
import ClerkKit

struct VerifyEmailView: View {
    @Environment(AppModel.self) private var model
    @State private var email = ""
    @State private var code = ""
    @State private var sentTo: String?
    @State private var busy = false
    @State private var error: String?
    @State private var cooldown = 0
    @FocusState private var focus: Field?
    enum Field { case email, code }

    private var domains: [String] { model.school?.domains ?? [] }
    private var emailValid: Bool {
        let e = email.lowercased().trimmingCharacters(in: .whitespaces)
        return e.contains("@") && domains.contains { e.hasSuffix("@" + $0.lowercased()) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Image(systemName: "checkmark.seal.fill").font(.largeTitle).foregroundStyle(.brand)
                        Text("Confirm you're a student").font(.title2.bold())
                        Text("We'll send a 6-digit code to your school email. \(model.school?.name ?? "Your school") sends it, not us.")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                    .listRowBackground(Color.clear)
                }
                Section {
                    TextField("you@\(domains.first ?? "school.edu")", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focus, equals: .email)
                        .disabled(sentTo != nil)
                } header: { Text("School email") } footer: {
                    if !email.isEmpty && !emailValid { Text("Use an address ending in \(domains.map { "@" + $0 }.joined(separator: " or ")).") }
                }
                if sentTo != nil {
                    Section {
                        TextField("123456", text: $code)
                            .keyboardType(.numberPad)
                            .textContentType(.oneTimeCode)
                            .font(.title2.monospacedDigit())
                            .focused($focus, equals: .code)
                            .onChange(of: code) { _, v in code = String(v.filter(\.isNumber).prefix(6)) }
                    } header: { Text("Code") } footer: {
                        HStack {
                            Text("Sent to \(sentTo ?? ""). It expires in 10 minutes.")
                            Spacer()
                            Button(cooldown > 0 ? "Resend in \(cooldown)s" : "Resend") { Task { await sendCode() } }
                                .disabled(cooldown > 0 || busy)
                                .font(.footnote.weight(.semibold))
                        }
                    }
                }
                if let error {
                    Section { Label(error, systemImage: "exclamationmark.circle").foregroundStyle(.red) }
                }
                Section {
                    Button {
                        Task { sentTo == nil ? await sendCode() : await verify() }
                    } label: {
                        HStack { Spacer(); if busy { ProgressView() } else { Text(sentTo == nil ? "Send Code" : "Verify").bold() }; Spacer() }
                    }
                    .disabled(busy || (sentTo == nil ? !emailValid : code.count != 6))
                    if sentTo != nil {
                        Button("Use a different email") { sentTo = nil; code = ""; error = nil }
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle("Verify")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Change School") { Task { await model.choose(nil) } }
                }
            }
            .onAppear { focus = .email }
            .task(id: cooldown) {
                guard cooldown > 0 else { return }
                try? await Task.sleep(for: .seconds(1))
                cooldown -= 1
            }
        }
    }

    private func sendCode() async {
        busy = true; error = nil
        defer { busy = false }
        do {
            let e = email.lowercased().trimmingCharacters(in: .whitespaces)
            try await model.send("/edu/send", body: ["email": e])
            sentTo = e
            cooldown = 60
            focus = .code
        } catch { self.error = error.localizedDescription }
    }

    private func verify() async {
        busy = true; error = nil
        defer { busy = false }
        do {
            try await model.send("/edu/verify", body: ["code": code])
            await model.refreshMe()
        } catch { self.error = error.localizedDescription }
    }
}
