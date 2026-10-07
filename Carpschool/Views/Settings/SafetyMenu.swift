import SwiftUI

/// Report / block actions for another student.
struct SafetyMenu: View {
    let subject: String
    let who: String
    var onBlocked: (() -> Void)? = nil

    @Environment(AppModel.self) private var model
    @State private var reporting = false
    @State private var confirmBlock = false
    @State private var reason = ""
    @State private var toast: Toast?

    var body: some View {
        Menu {
            Button("Report \(who.capitalized)…", systemImage: "exclamationmark.bubble") { reporting = true }
            Button("Block", systemImage: "hand.raised", role: .destructive) { confirmBlock = true }
        } label: {
            Label("Safety", systemImage: "ellipsis.circle")
        }
        .alert("Report \(who)", isPresented: $reporting) {
            TextField("What happened?", text: $reason, axis: .vertical)
            Button("Send Report") { Task { await report() } }.disabled(reason.trimmingCharacters(in: .whitespaces).count < 5)
            Button("Cancel", role: .cancel) { reason = "" }
        } message: { Text("School admins review every report.") }
        .confirmationDialog("Block \(who)?", isPresented: $confirmBlock, titleVisibility: .visible) {
            Button("Block", role: .destructive) { Task { await block() } }
        } message: { Text("You won't be matched or chat with them again. Unblock any time in Settings.") }
        .toast($toast)
    }

    private func report() async {
        do { try await model.send("/reports", body: ["subject": subject, "reason": reason]); reason = ""; toast = Toast(text: "Report sent") }
        catch { toast = Toast(text: error.localizedDescription, isError: true) }
    }

    private func block() async {
        do { try await model.send("/blocks", body: ["subject": subject]); model.revision += 1; onBlocked?() }
        catch { toast = Toast(text: error.localizedDescription, isError: true) }
    }
}
