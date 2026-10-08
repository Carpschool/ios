import SwiftUI
import ClerkKit

struct SchoolPickerView: View {
    @Environment(AppModel.self) private var model
    @State private var query = ""
    @State private var choosing: String?

    private var filtered: [School] {
        let all = model.schools ?? []
        guard !query.isEmpty else { return all }
        return all.filter { $0.name.localizedCaseInsensitiveContains(query) || $0.domains.contains { $0.localizedCaseInsensitiveContains(query) } }
    }

    var body: some View {
        NavigationStack {
            Group {
                if let err = model.schoolsError {
                    ErrorBanner(message: err) { Task { await model.loadSchools() } }
                } else if model.schools == nil {
                    ProgressView()
                } else if filtered.isEmpty {
                    ContentUnavailableView.search(text: query)
                } else {
                    List(filtered) { s in
                        Button {
                            choosing = s.schoolCode
                            Task { await model.choose(s); choosing = nil }
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: "building.columns.fill")
                                    .font(.title3)
                                    .foregroundStyle(.white)
                                    .frame(width: 42, height: 42)
                                    .background(Color.brand.gradient, in: .rect(cornerRadius: 10))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(s.name).font(.headline).foregroundStyle(.primary)
                                    Text(s.domains.map { "@" + $0 }.joined(separator: ", ")).font(.subheadline).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if choosing == s.schoolCode { ProgressView() } else { Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary) }
                            }
                            .padding(.vertical, 4)
                        }
                        .disabled(choosing != nil)
                    }
                    .refreshable { await model.loadSchools() }
                }
            }
            .navigationTitle("Your School")
            .searchable(text: $query, prompt: "Search schools")
            .safeAreaInset(edge: .top) {
                Text("Only schools trusted by the Carpschool network are listed.")
                    .font(.footnote).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20).padding(.bottom, 4)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Sign Out") { Task { try? await Clerk.shared.auth.signOut() } }
                }
            }
        }
    }
}
