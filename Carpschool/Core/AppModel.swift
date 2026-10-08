import Foundation
import Observation
import ClerkKit

struct APIError: LocalizedError {
    let message: String
    let status: Int
    var errorDescription: String? { message }
}

enum LoadState: Equatable { case idle, loading, ready, failed(String) }

/// Owns the central registry, the chosen school and the short-lived school session token.
@MainActor
@Observable
final class AppModel {
    private(set) var schools: [School]?
    private(set) var schoolsError: String?
    private(set) var schoolCode: String? = UserDefaults.standard.string(forKey: "schoolCode")
    private(set) var meta: SchoolMeta?
    private(set) var me: Me?
    private(set) var meState: LoadState = .idle
    /// Bumped after mutations so lists can reload.
    var revision = 0

    @ObservationIgnored private var session: (code: String, user: String, token: String, exp: Date)?
    @ObservationIgnored private var inflight: Task<String, Error>?

    var school: School? { schools?.first { $0.schoolCode == schoolCode } }
    var isDriver: Bool { me?.role == .driver }
    var central: String { AppConfig.centralURL.trimmingCharacters(in: CharacterSet(charactersIn: "/ ")) }

    // MARK: Central

    func loadSchools() async {
        schoolsError = nil
        do {
            guard let url = URL(string: central + "/schools") else { throw APIError(message: "Bad network address", status: 0) }
            let (data, resp) = try await URLSession.shared.data(from: url)
            schools = try Self.decode([School].self, data, resp)
            if school != nil { await loadMeta() }
        } catch {
            schools = nil
            schoolsError = "Couldn't reach the Carpschool network."
        }
    }

    func choose(_ s: School?) async {
        session = nil
        schoolCode = s?.schoolCode
        UserDefaults.standard.set(s?.schoolCode, forKey: "schoolCode")
        me = nil
        meta = nil
        meState = .idle
        if s != nil {
            await loadMeta()
            await refreshMe()
        }
    }

    private func loadMeta() async {
        guard let s = school, let url = URL(string: s.baseUrl + "/.well-known/carpschool.json") else { return }
        if let (data, resp) = try? await URLSession.shared.data(from: url) {
            meta = try? Self.decode(SchoolMeta.self, data, resp)
        }
    }

    private func clerkToken() async throws -> String {
        guard let t = try await Clerk.shared.auth.getToken() else { throw APIError(message: "You're signed out.", status: 401) }
        return t
    }

    private func schoolToken(force: Bool = false) async throws -> String {
        guard let s = school, let user = Clerk.shared.user?.id else { throw APIError(message: "Pick a school first.", status: 400) }
        if !force, let t = session, t.code == s.schoolCode, t.user == user, t.exp.timeIntervalSinceNow > 30 { return t.token }
        if let inflight { return try await inflight.value }
        let task = Task<String, Error> {
            defer { self.inflight = nil }
            let jwt = try await clerkToken()
            var req = URLRequest(url: URL(string: central + "/tickets")!)
            req.httpMethod = "POST"
            req.setValue("Bearer " + jwt, forHTTPHeaderField: "Authorization")
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONSerialization.data(withJSONObject: ["schoolCode": s.schoolCode])
            struct Ticket: Decodable { let ticket: String }
            let (td, tr) = try await URLSession.shared.data(for: req)
            let ticket = try Self.decode(Ticket.self, td, tr).ticket

            var sreq = URLRequest(url: URL(string: s.baseUrl + "/sessions")!)
            sreq.httpMethod = "POST"
            sreq.setValue("application/json", forHTTPHeaderField: "Content-Type")
            sreq.httpBody = try JSONSerialization.data(withJSONObject: ["ticket": ticket])
            struct Sess: Decodable { let token: String; let expiresAt: String }
            let (sd, sr) = try await URLSession.shared.data(for: sreq)
            let sess = try Self.decode(Sess.self, sd, sr)
            let exp = Fmt.date(sess.expiresAt) ?? .now.addingTimeInterval(600)
            self.session = (s.schoolCode, user, sess.token, exp)
            return sess.token
        }
        inflight = task
        return try await task.value
    }

    /// Token for the Socket.IO handshake.
    func socketToken() async throws -> String { try await schoolToken() }

    // MARK: School API

    @discardableResult
    func send(_ path: String, method: String? = nil, body: [String: Any]? = nil) async throws -> Data {
        guard let s = school, let url = URL(string: s.baseUrl + path) else { throw APIError(message: "Pick a school first.", status: 400) }
        func go(_ force: Bool) async throws -> (Data, URLResponse) {
            var req = URLRequest(url: url)
            req.httpMethod = method ?? (body == nil ? "GET" : "POST")
            req.setValue("Bearer " + (try await schoolToken(force: force)), forHTTPHeaderField: "Authorization")
            if let body {
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                req.httpBody = try JSONSerialization.data(withJSONObject: body)
            }
            return try await URLSession.shared.data(for: req)
        }
        var (data, resp) = try await go(false)
        if (resp as? HTTPURLResponse)?.statusCode == 401 { (data, resp) = try await go(true) }
        try Self.check(data, resp)
        return data
    }

    func get<T: Decodable>(_ type: T.Type = T.self, _ path: String, method: String? = nil, body: [String: Any]? = nil) async throws -> T {
        let data = try await send(path, method: method, body: body)
        return try JSONDecoder().decode(T.self, from: data.isEmpty ? Data("null".utf8) : data)
    }

    func refreshMe() async {
        guard school != nil else { return }
        if me == nil { meState = .loading }
        do {
            me = try await get(Me?.self, "/me")
            meState = .ready
        } catch {
            meState = .failed(error.localizedDescription)
        }
    }

    func signedOut() {
        session = nil
        me = nil
        meState = .idle
    }

    // MARK: Helpers

    nonisolated static func check(_ data: Data, _ resp: URLResponse) throws {
        guard let http = resp as? HTTPURLResponse, !(200..<300).contains(http.statusCode) else { return }
        var msg = HTTPURLResponse.localizedString(forStatusCode: http.statusCode).capitalized
        if let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let m = j["message"] ?? j["error"]
            if let s = m as? String { msg = s }
            else if let a = m as? [String] { msg = a.joined(separator: ". ") }
            else if let o = m as? [String: Any] {
                var parts = (o["formErrors"] as? [String]) ?? []
                if let fe = o["fieldErrors"] as? [String: [String]] { parts += fe.map { "\($0.key): \($0.value.first ?? "")" } }
                msg = parts.isEmpty ? "Check the form and try again." : parts.joined(separator: ". ")
            }
        }
        if http.statusCode == 429 { msg = "Too many tries. Wait a minute and try again." }
        throw APIError(message: msg, status: http.statusCode)
    }

    nonisolated static func decode<T: Decodable>(_ t: T.Type, _ data: Data, _ resp: URLResponse) throws -> T {
        try check(data, resp)
        return try JSONDecoder().decode(T.self, from: data)
    }
}
