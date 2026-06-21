import Network
import Foundation

enum ProtocolError: Error {
    case badFrame
    case badJSON
    case disconnected
}

final class ControlChannel {
    private let endpoint: NWEndpoint
    private let udpPort: Int
    private let capabilities: HapticCapabilities
    private var conn: NWConnection?

    var onConnected: ((String) -> Void)?
    var onDisconnected: (() -> Void)?
    var onTimeline: (([String: Any]) -> Void)?
    var onPlay: ((Double, Int64, Double) -> Void)?
    var onPause: ((Double, Int64) -> Void)?
    var onSeek: ((Double, Int64) -> Void)?
    var onRate: ((Double, Int64) -> Void)?
    var onTimeResp: ((Int64, Int64, Int64) -> Void)?

    init(endpoint: NWEndpoint, udpPort: Int, capabilities: HapticCapabilities) {
        self.endpoint = endpoint
        self.udpPort = udpPort
        self.capabilities = capabilities
    }

    func connect() {
        let c = NWConnection(to: endpoint, using: .tcp)
        conn = c
        c.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                sendHello()
                receiveLoop()
                onConnected?(resolvedServerAddress())
            case .failed, .cancelled:
                onDisconnected?()
            default:
                break
            }
        }
        c.start(queue: DispatchQueue.main)
    }

    func disconnect() {
        conn?.cancel()
        conn = nil
    }

    func send(_ json: [String: Any]) {
        guard let conn, let body = try? JSONSerialization.data(withJSONObject: json) else { return }
        var length = UInt32(body.count).bigEndian
        var frame = Data(bytes: &length, count: 4)
        frame.append(body)
        conn.send(content: frame, completion: .idempotent)
    }

    // Returns the resolved IP for direct hostPort connections.
    // Bonjour service endpoints resolve internally — NWConnection doesn't expose
    // the IP through its public API, so we return empty and the caller uses the service name.
    private func resolvedServerAddress() -> String {
        guard let c = conn else { return "" }
        if case .hostPort(let host, let port) = c.endpoint {
            return "\(host):\(port)"
        }
        return ""
    }

    private func sendHello() {
        let hello: [String: Any] = [
            "msg": "hello",
            "client": "ios-haptic",
            "client_version": "0.1",
            "udp_port": udpPort,
            "capabilities": [
                "amplitude_control": capabilities.supportsHaptics,
                "primitives": supportedPrimitiveNames(capabilities),
                "vibrator_api": Int(ProcessInfo.processInfo.operatingSystemVersion.majorVersion)
            ] as [String: Any]
        ]
        send(hello)
    }

    private func receiveLoop() {
        Task {
            while !Task.isCancelled {
                do {
                    let (msg, receiveNs) = try await receiveMessage()
                    dispatch(msg, receiveNs: receiveNs)
                } catch {
                    onDisconnected?()
                    break
                }
            }
        }
    }

    private func receiveMessage() async throws -> ([String: Any], Int64) {
        let header = try await readBytes(exactly: 4)
        let length = Int(header.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian })
        guard length > 0, length <= 64 * 1024 * 1024 else { throw ProtocolError.badFrame }
        let (body, receiveNs) = try await readBytes(exactly: length, captureTimestamp: true)
        guard let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any]
        else { throw ProtocolError.badJSON }
        return (json, receiveNs)
    }

    private func readBytes(exactly count: Int) async throws -> Data {
        try await readBytes(exactly: count, captureTimestamp: false).0
    }

    private func readBytes(exactly count: Int, captureTimestamp: Bool) async throws -> (Data, Int64) {
        guard let conn else { throw ProtocolError.disconnected }
        var accumulated = Data()
        var lastTs: Int64 = 0
        while accumulated.count < count {
            let remaining = count - accumulated.count
            let (chunk, ts): (Data, Int64) = try await withCheckedThrowingContinuation { cont in
                conn.receive(minimumIncompleteLength: 1, maximumLength: remaining) { data, _, _, error in
                    let ts = captureTimestamp ? nanoTime() : 0
                    if let error { cont.resume(throwing: error); return }
                    guard let data, !data.isEmpty else {
                        cont.resume(throwing: ProtocolError.disconnected)
                        return
                    }
                    cont.resume(returning: (data, ts))
                }
            }
            accumulated.append(chunk)
            if captureTimestamp { lastTs = ts }
        }
        return (accumulated, lastTs)
    }

    private func dispatch(_ msg: [String: Any], receiveNs: Int64) {
        switch msg["msg"] as? String {
        case "timeline":
            if let data = msg["data"] as? [String: Any] { onTimeline?(data) }
        case "play":
            if let t      = msg["media_t"]    as? Double,
               let ts     = jsonInt64(msg, "t_server_ns"),
               let rate   = msg["rate"]       as? Double {
                onPlay?(t, ts, rate)
            }
        case "pause":
            if let t  = msg["media_t"]    as? Double,
               let ts = jsonInt64(msg, "t_server_ns") {
                onPause?(t, ts)
            }
        case "seek":
            if let t  = msg["media_t"]    as? Double,
               let ts = jsonInt64(msg, "t_server_ns") {
                onSeek?(t, ts)
            }
        case "rate":
            if let rate = msg["rate"]        as? Double,
               let ts   = jsonInt64(msg, "t_server_ns") {
                onRate?(rate, ts)
            }
        case "time_resp":
            if let t0 = jsonInt64(msg, "t0_client_ns"),
               let ts = jsonInt64(msg, "t_server_ns") {
                onTimeResp?(t0, ts, receiveNs)
            }
        default:
            break
        }
    }
}

private func jsonInt64(_ msg: [String: Any], _ key: String) -> Int64? {
    if let v = msg[key] as? Int    { return Int64(v) }
    if let v = msg[key] as? Int64  { return v }
    return (msg[key] as? NSNumber)?.int64Value
}
