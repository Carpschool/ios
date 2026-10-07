import SwiftUI

struct ChatsView: View {
    @Environment(AppModel.self) private var model
    @State private var chats: [Negotiation]?
    @State private var error: String?

    var body: some View {
        Group {
            if let chats {
                if chats.isEmpty {
                    ContentUnavailableView("No chats yet", systemImage: "bubble.left.and.bubble.right",
                                           description: Text(model.isDriver ? "Reach out to a rider from one of your drives." : "When a driver reaches out, the chat shows up here."))
                } else {
                    List(chats.sorted { ($0.updatedAt ?? "") > ($1.updatedAt ?? "") }) { n in
                        let other = model.isDriver ? n.rider : n.driver
                        NavigationLink(value: Route.chat(n.id)) {
                            HStack(spacing: 12) {
                                InitialsAvatar(id: other, size: 44)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("\(model.isDriver ? "Rider" : "Driver") \(Fmt.shortId(other))").font(.headline)
                                    Text(n.status == "open" ? "Negotiating pickup" : "Carpool locked")
                                        .font(.subheadline)
                                        .foregroundStyle(n.status == "open" ? Color.secondary : Color.green)
                                }
                                Spacer()
                                Text(Fmt.ago(n.updatedAt)).font(.caption).foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            } else if let error {
                ErrorBanner(message: error) { Task { await load() } }
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Chats")
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        do { chats = try await model.get([Negotiation].self, "/negotiations"); error = nil }
        catch { self.error = error.localizedDescription }
    }
}
