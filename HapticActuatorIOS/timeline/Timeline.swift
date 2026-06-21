import Foundation

struct HapticEvent {
    let time: Double
    let intensity: Float
    let visionType: String?
}

struct Timeline {
    let events: [HapticEvent]

    static func parse(_ data: [String: Any]) -> Timeline {
        let raw = data["events"] as? [[String: Any]] ?? []
        let events = raw.compactMap { e -> HapticEvent? in
            guard let time = e["time"] as? Double,
                  let intensity = (e["intensity"] as? NSNumber).map({ Float($0.doubleValue) })
            else { return nil }
            let visionType = e["vision_type"] as? String
            return HapticEvent(time: time, intensity: intensity, visionType: visionType)
        }.sorted { $0.time < $1.time }
        return Timeline(events: events)
    }

    // Binary search: first index with event.time >= t
    func indexFrom(_ t: Double) -> Int {
        var lo = 0, hi = events.count
        while lo < hi {
            let mid = (lo + hi) / 2
            if events[mid].time < t { lo = mid + 1 } else { hi = mid }
        }
        return lo
    }
}
