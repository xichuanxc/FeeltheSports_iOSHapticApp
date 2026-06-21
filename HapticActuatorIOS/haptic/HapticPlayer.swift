import CoreHaptics
import UIKit

struct BatchEvent {
    let visionType: String?
    let intensity: Float
    let delayFromFirstS: Double
}

final class HapticPlayer {
    private let capabilities: HapticCapabilities
    private var engine: CHHapticEngine?
    private var engineReady = false

    // Strong references keep players alive until CoreHaptics finishes playing them.
    // A ring buffer of 8 is far more than enough — haptics are 80–120 ms.
    private var retainedPlayers: [CHHapticPatternPlayer] = []

    init(capabilities: HapticCapabilities) {
        self.capabilities = capabilities
    }

    func setupEngine() throws {
        guard capabilities.tier == .coreHaptics else { return }
        let e = try CHHapticEngine()

        // CoreHaptics calls these from a background thread — hop to MainActor.
        e.stoppedHandler = { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.engineReady = false
                self?.restartEngine()
            }
        }
        e.resetHandler = { [weak self] in
            Task { @MainActor [weak self] in
                self?.engineReady = false
                self?.restartEngine()
            }
        }

        try e.start()
        engine = e
        engineReady = true
    }

    private func restartEngine() {
        guard let engine else { return }
        do {
            try engine.start()
            engineReady = true
        } catch {
            // Schedule one retry after 200 ms; if that fails, the next play attempt will try again.
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 200_000_000)
                guard let self, !engineReady else { return }
                try? await engine.start()
                engineReady = true
            }
        }
    }

    // MARK: - Public API

    func play(visionType: String?, intensity: Float = 1.0) {
        playBatch([BatchEvent(visionType: visionType, intensity: intensity, delayFromFirstS: 0)])
    }

    func playBatch(_ batch: [BatchEvent]) {
        guard !batch.isEmpty else { return }
        switch capabilities.tier {
        case .coreHaptics:
            batch.count == 1
                ? playSingle(batch[0])
                : playCompositionBatch(batch)
        case .uiImpact:
            batch.forEach { playImpact($0) }
        case .none:
            break
        }
    }

    func estimateBatchDuration(_ batch: [BatchEvent]) -> Double {
        guard capabilities.tier == .coreHaptics, let last = batch.last else { return 0 }
        return last.delayFromFirstS + eventDuration(for: last.visionType) + 0.02
    }

    // MARK: - CoreHaptics

    private func playSingle(_ e: BatchEvent) {
        guard engineReady, let engine else { return }
        let event = makeHapticEvent(e, relativeTime: 0)
        guard let pattern = try? CHHapticPattern(events: [event], parameters: []),
              let player  = try? engine.makePlayer(with: pattern)
        else { return }
        retain(player)
        try? player.start(atTime: CHHapticTimeImmediate)
    }

    private func playCompositionBatch(_ batch: [BatchEvent]) {
        guard engineReady, let engine else { return }
        let events = batch.map { makeHapticEvent($0, relativeTime: $0.delayFromFirstS) }
        guard let pattern = try? CHHapticPattern(events: events, parameters: []),
              let player  = try? engine.makePlayer(with: pattern)
        else { return }
        retain(player)
        try? player.start(atTime: CHHapticTimeImmediate)
    }

    private func retain(_ player: CHHapticPatternPlayer) {
        retainedPlayers.append(player)
        if retainedPlayers.count > 8 { retainedPlayers.removeFirst() }
    }

    // Strike: transient — sharp instantaneous crack, full strength.
    // Bounce: continuous 0.12 s — heavy rounded thud.
    // Neutral: continuous 0.08 s — solid mid-weight hit.
    // Floor of 0.55 ensures nothing that fires is imperceptible.
    private func makeHapticEvent(_ e: BatchEvent, relativeTime: TimeInterval) -> CHHapticEvent {
        let raw = max(e.intensity, 0.55)
        switch e.visionType {
        case "strike":
            return CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    .init(parameterID: .hapticIntensity, value: min(raw * 1.05, 1.0)),
                    .init(parameterID: .hapticSharpness, value: 0.95)
                ],
                relativeTime: relativeTime
            )
        case "bounce":
            return CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    .init(parameterID: .hapticIntensity, value: min(raw * 0.90, 1.0)),
                    .init(parameterID: .hapticSharpness, value: 0.05)
                ],
                relativeTime: relativeTime,
                duration: 0.12
            )
        default:
            return CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    .init(parameterID: .hapticIntensity, value: min(raw * 0.95, 1.0)),
                    .init(parameterID: .hapticSharpness, value: 0.5)
                ],
                relativeTime: relativeTime,
                duration: 0.08
            )
        }
    }

    private func eventDuration(for visionType: String?) -> Double {
        switch visionType {
        case "bounce": return 0.12
        case "strike": return 0.0
        default:       return 0.08
        }
    }

    // MARK: - UIImpact fallback (tier 2)

    private func playImpact(_ e: BatchEvent) {
        let style: UIImpactFeedbackGenerator.FeedbackStyle
        switch e.visionType {
        case "strike": style = .rigid
        case "bounce": style = .soft
        default:       style = e.intensity > 0.6 ? .heavy : e.intensity > 0.3 ? .medium : .light
        }
        let gen = UIImpactFeedbackGenerator(style: style)
        gen.prepare()
        gen.impactOccurred(intensity: CGFloat(min(e.intensity * 1.2, 1.0)))
    }
}
