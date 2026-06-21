import Darwin

nonisolated func nanoTime() -> Int64 {
    var ts = timespec()
    clock_gettime(CLOCK_MONOTONIC, &ts)
    return Int64(ts.tv_sec) * 1_000_000_000 + Int64(ts.tv_nsec)
}

final class MediaClock {
    private struct Anchor {
        var mediaT:   Double
        var serverNs: Int64
        var rate:     Double
    }
    private var anchor: Anchor?
    private(set) var clockOffsetNs: Int64 = 0

    var isPlaying: Bool { (anchor?.rate ?? 0.0) != 0.0 }
    var rate: Double    { anchor?.rate ?? 1.0 }

    func mediaTime() -> Double {
        guard let a = anchor else { return 0.0 }
        if a.rate == 0.0 { return a.mediaT }
        return a.mediaT + Double(nowServerNs() - a.serverNs) / 1_000_000_000.0 * a.rate
    }

    private func nowServerNs() -> Int64 { nanoTime() + clockOffsetNs }

    func syncAnchor(mediaT: Double, serverNs: Int64, rate: Double) {
        anchor = Anchor(mediaT: mediaT, serverNs: serverNs, rate: rate)
    }

    func setOffset(_ offsetNs: Int64) {
        let delta = offsetNs - clockOffsetNs
        clockOffsetNs = offsetNs
        anchor = anchor.map { Anchor(mediaT: $0.mediaT, serverNs: $0.serverNs + delta, rate: $0.rate) }
    }
}
