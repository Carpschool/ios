import SwiftUI

struct SchoolSelectView: View {
    var onSchoolConnected: (School) -> Void

    @State private var schools: [School] = []
    @State private var customUrl: String = ""
    @State private var showUntrustedAlert = false
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            List {
                Section("Verified School Directory") {
                    // Sample verified schools
                    Button {
                        connectToSchool(code: "ubc", name: "University of British Columbia", url: "https://ubc.carp.school", isTrusted: true)
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("University of British Columbia").font(.headline)
                                Text("https://ubc.carp.school").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
                        }
                    }
                }

                Section("Custom / Self-Hosted School") {
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("https://rides.myschool.org", text: $customUrl)
                            .textFieldStyle(.roundedBorder)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()

                        if !customUrl.isEmpty {
                            Label("Untrusted server: Not verified by Carpschool", systemImage: "exclamationmark.triangle.fill")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }

                        Button("Connect to Custom Server") {
                            showUntrustedAlert = true
                        }
                        .disabled(customUrl.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
            .navigationTitle("Select School")
            .alert("Connect to Untrusted Server?", isPresented: $showUntrustedAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Proceed Anyway", role: .destructive) {
                    connectToSchool(code: "custom", name: "Custom School", url: customUrl, isTrusted: false)
                }
            } message: {
                Text("This school server is self-hosted and has not been verified by Carpschool administrators.")
            }
        }
    }

    private func connectToSchool(code: String, name: String, url: String, isTrusted: Bool) {
        let school = School(schoolCode: code, officialName: name, allowedEmailDomains: [], baseUrl: url, isTrusted: isTrusted)
        onSchoolConnected(school)
    }
}
