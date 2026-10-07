import Foundation
import Observation
@preconcurrency import SocketIO

/// One Socket.IO connection per open chat. Auth uses the school session token.
@MainActor
@Observable
final class ChatSocket {
    enum State { case connecting, live, offline }
    private(set) var state: State = .connecting
    var messages: [ChatMessage] = []
    var proposals: [Proposal] = []
    var lockedDrive: String?
    var lastError: String?

    @ObservationIgnored private var manager: SocketManager?
    @ObservationIgnored private var socket: SocketIOClient?
    @ObservationIgnored private var pending: ((String) -> Void)?
    let negotiationId: String

    init(negotiationId: String) { self.negotiationId = negotiationId }

    func connect(baseURL: String, token: @escaping @MainActor () async throws -> String) async {
        guard socket == nil, let url = URL(string: baseURL) else { return }
        let m = SocketManager(socketURL: url, config: [.log(false), .forceWebsockets(true), .reconnects(true), .reconnectWait(2), .reconnectAttempts(5)])
        let s = m.defaultSocket
        manager = m
        socket = s
        let nid = negotiationId

        s.on(clientEvent: .connect) { [weak self] _, _ in
            MainActor.assumeIsolated {
                guard let self, let s = self.socket else { return }
                s.emitWithAck("negotiation:join", ["negotiationId": nid]).timingOut(after: 10) { [weak self] data in
                    MainActor.assumeIsolated {
                        let ok = ((data.first as? [String: Any])?["ok"] as? Bool) != false
                        self?.state = ok ? .live : .offline
                    }
                }
            }
        }
        s.on(clientEvent: .disconnect) { [weak self] _, _ in MainActor.assumeIsolated { self?.state = .offline } }
        s.on(clientEvent: .error) { [weak self] _, _ in MainActor.assumeIsolated { self?.state = .offline } }
        s.on("exception") { [weak self] data, _ in
            MainActor.assumeIsolated {
                let msg = ((data.first as? [String: Any])?["message"] as? String) ?? "Request rejected"
                if let p = self?.pending { p(msg); self?.pending = nil } else { self?.lastError = msg }
            }
        }
        s.on("message:new") { [weak self] data, _ in
            MainActor.assumeIsolated {
                guard let self, let m: ChatMessage = Self.decode(data.first), m.negotiationId == nid else { return }
                if !self.messages.contains(where: { $0.id == m.id }) { self.messages.append(m) }
            }
        }
        s.on("proposal:new") { [weak self] data, _ in
            MainActor.assumeIsolated {
                guard let self, let p: Proposal = Self.decode(data.first), p.negotiationId == nid else { return }
                self.upsert(p)
            }
        }
        s.on("carpool:locked") { [weak self] data, _ in
            MainActor.assumeIsolated {
                self?.lockedDrive = (data.first as? [String: Any])?["driveId"] as? String
            }
        }

        do {
            let t = try await token()
            s.connect(withPayload: ["token": t])
        } catch {
            state = .offline
        }
    }

    func disconnect() {
        socket?.disconnect()
        socket = nil
        manager = nil
    }

    func upsert(_ p: Proposal) {
        if let i = proposals.firstIndex(where: { $0.id == p.id }) { proposals[i] = p } else { proposals.append(p) }
    }

    /// Emits with ack. Server acks {ok:true,data}; rejections arrive as "exception".
    func emit(_ event: String, _ payload: [String: Any]) async throws -> Data? {
        guard let s = socket, s.status == .connected else { throw APIError(message: "Not connected yet. Try again in a moment.", status: 0) }
        var body = payload
        body["negotiationId"] = negotiationId
        return try await withCheckedThrowingContinuation { (c: CheckedContinuation<Data?, Error>) in
            var done = false
            pending = { msg in if !done { done = true; c.resume(throwing: APIError(message: msg, status: 400)) } }
            s.emitWithAck(event, body).timingOut(after: 10) { [weak self] data in
                MainActor.assumeIsolated {
                    guard !done else { return }
                    done = true
                    self?.pending = nil
                    if let first = data.first as? String, first == SocketAckStatus.noAck.rawValue {
                        c.resume(throwing: APIError(message: "Timed out. Check your connection.", status: 0)); return
                    }
                    let a = data.first as? [String: Any]
                    if a?["ok"] as? Bool == false {
                        let e = a?["error"]
                        let msg = (e as? String) ?? ((e as? [String: Any])?["message"] as? String) ?? (a?["message"] as? String) ?? "Something went wrong"
                        c.resume(throwing: APIError(message: msg, status: 400)); return
                    }
                    let v: Any? = a?["data"] ?? a
                    c.resume(returning: v.flatMap { JSONSerialization.isValidJSONObject($0) ? try? JSONSerialization.data(withJSONObject: $0) : nil })
                }
            }
        }
    }

    nonisolated static func decode<T: Decodable>(_ data: Data?) -> T? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    nonisolated static func decode<T: Decodable>(_ any: Any?) -> T? {
        guard let any, JSONSerialization.isValidJSONObject(any), let d = try? JSONSerialization.data(withJSONObject: any) else { return nil }
        return try? JSONDecoder().decode(T.self, from: d)
    }
}

