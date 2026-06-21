import Foundation

final class Scheduler {
    private var currentTask: Task<Void, Never>?

    private let staleThresholdS: Double = 0.3
    private let maxSleepMs: Int64       = 200
    private let batchWindowS: Double    = 0.2

    func start(timeline: Timeline, mediaClock: MediaClock, player: HapticPlayer,
               strengthScale: Float, minIntensity: Float) {
        currentTask?.cancel()
        currentTask = Task {
            var i = timeline.indexFrom(mediaClock.mediaTime())

            while i < timeline.events.count, !Task.isCancelled {
                let event = timeline.events[i]

                while !Task.isCancelled {
                    let rate = max(mediaClock.rate, 0.01)
                    let remainingMs = Int64(((event.time - mediaClock.mediaTime()) / rate) * 1000)
                    if remainingMs <= 1 { break }
                    try? await Task.sleep(nanoseconds: UInt64(min(remainingMs, maxSleepMs)) * 1_000_000)
                }
                if Task.isCancelled { break }

                if event.time < mediaClock.mediaTime() - staleThresholdS {
                    i += 1; continue
                }

                let scaled = min(max(event.intensity * strengthScale, 0), 1)
                if scaled < minIntensity { i += 1; continue }

                var batch = [BatchEvent(visionType: event.visionType, intensity: scaled, delayFromFirstS: 0)]
                var j = i + 1
                while j < timeline.events.count {
                    let next = timeline.events[j]
                    let gapS = next.time - event.time
                    if gapS > batchWindowS { break }
                    let nextScaled = min(max(next.intensity * strengthScale, 0), 1)
                    if nextScaled >= minIntensity {
                        batch.append(BatchEvent(visionType: next.visionType,
                                                intensity: nextScaled,
                                                delayFromFirstS: gapS))
                    }
                    j += 1
                }

                let batchDurationS = player.estimateBatchDuration(batch)
                player.playBatch(batch)

                let compositionEndsAtS = event.time + batchDurationS
                let rate = max(mediaClock.rate, 0.01)
                let guardMs = Int64(((compositionEndsAtS - mediaClock.mediaTime()) / rate) * 1000)
                if guardMs > 1 {
                    try? await Task.sleep(nanoseconds: UInt64(min(guardMs, maxSleepMs)) * 1_000_000)
                }

                i = j
            }
        }
    }

    func stop() {
        currentTask?.cancel()
        currentTask = nil
    }
}
