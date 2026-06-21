import Foundation

final class ClockSync {
    private var continuation: AsyncStream<(rtt: Int64, offset: Int64)>.Continuation?
    private var stream: AsyncStream<(rtt: Int64, offset: Int64)>?

    func onTimeResp(t0: Int64, tServer: Int64, t1: Int64) {
        let rtt    = t1 - t0
        let offset = tServer - (t0 + rtt / 2)
        continuation?.yield((rtt: rtt, offset: offset))
    }

    func sync(send: ([String: Any]) -> Void, rounds: Int = 8) async -> Int64 {
        var cont: AsyncStream<(rtt: Int64, offset: Int64)>.Continuation?
        stream = AsyncStream { cont = $0 }
        continuation = cont

        for _ in 0..<rounds {
            let t0 = nanoTime()
            send(["msg": "time_req", "t0_client_ns": t0])
            try? await Task.sleep(nanoseconds: 20_000_000)
        }

        var results: [(rtt: Int64, offset: Int64)] = []
        let deadline = ContinuousClock.now + .seconds(2)
        if let stream {
            for await sample in stream {
                results.append(sample)
                if results.count >= rounds || ContinuousClock.now > deadline { break }
            }
        }

        continuation?.finish()
        continuation = nil
        self.stream = nil

        guard !results.isEmpty else { return 0 }
        let sorted = results.sorted { $0.rtt < $1.rtt }
        let kept   = sorted.prefix(max(1, sorted.count / 2))
        return kept.map(\.offset).reduce(0, +) / Int64(kept.count)
    }
}
