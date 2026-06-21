import Network
import Foundation

final class SyncChannel {
    private var listener: NWListener?
    private(set) var port: Int = 0
    var onSyncPulse: ((Double, Int64, Double) -> Void)?

    func start() async {
        guard let l = try? NWListener(using: .udp) else { return }
        listener = l

        l.newConnectionHandler = { [weak self] conn in
            conn.start(queue: DispatchQueue.main)
            self?.receiveSync(from: conn)
        }

        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            var resumed = false
            l.stateUpdateHandler = { [weak self] state in
                switch state {
                case .ready:
                    if let p = self?.listener?.port {
                        self?.port = Int(p.rawValue)
                    }
                    if !resumed { resumed = true; cont.resume() }
                case .failed:
                    if !resumed { resumed = true; cont.resume() }
                default:
                    break
                }
            }
            l.start(queue: DispatchQueue.main)
        }
    }

    func close() {
        listener?.cancel()
        listener = nil
    }

    private func receiveSync(from conn: NWConnection) {
        conn.receiveMessage { [weak self] data, _, _, error in
            guard let self else { return }
            guard error == nil,
                  let data,
                  let json    = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  json["msg"] as? String == "sync",
                  let mediaT   = json["media_t"]    as? Double,
                  let serverNs = (json["t_server_ns"] as? NSNumber)?.int64Value,
                  let rate     = json["rate"]        as? Double
            else {
                if error == nil { receiveSync(from: conn) }
                return
            }
            onSyncPulse?(mediaT, serverNs, rate)
            receiveSync(from: conn)
        }
    }
}
