import Network
import Foundation
import Observation

enum ConnectionStatus: Equatable {
    case searching
    case connecting(name: String)
    case reconnecting(name: String)
    case connected(name: String)
}

@Observable
final class AppState {
    var connectionStatus: ConnectionStatus = .searching
    var eventCount: Int?       = nil
    var clockOffsetMs: Int64?  = nil
    var lastSyncMediaT: Double? = nil
    var strengthScale: Float = 1.5 {
        didSet { UserDefaults.standard.set(strengthScale, forKey: "strength_scale") }
    }
    var filterWeakEvents: Bool = false {
        didSet { UserDefaults.standard.set(filterWeakEvents, forKey: "filter_weak_events") }
    }

    var effectiveMinIntensity: Float { filterWeakEvents ? 0.15 : 0.0 }

    var showDNDPrompt: Bool = false
    private(set) var dndNeverAsk: Bool = false {
        didSet { UserDefaults.standard.set(dndNeverAsk, forKey: "dnd_never_ask") }
    }

    func dismissDNDPrompt(permanently: Bool) {
        showDNDPrompt = false
        if permanently { dndNeverAsk = true }
    }

    let mediaClock   = MediaClock()
    let scheduler    = Scheduler()
    let hapticPlayer: HapticPlayer
    let capabilities: HapticCapabilities

    private var discovery:      Discovery?
    private var controlChannel: ControlChannel?
    private var syncChannel:    SyncChannel?
    private var clockSync:      ClockSync?
    private var currentTimeline: Timeline?

    private var lastEndpoint: NWEndpoint?
    private var lastName:     String = ""
    private var reconnectDelay:    TimeInterval = 1.0
    private let reconnectDelayMin: TimeInterval = 1.0
    private let reconnectDelayMax: TimeInterval = 30.0
    private var reconnectTask: Task<Void, Never>?
    private var connectTask:   Task<Void, Never>?

    init() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "strength_scale") != nil {
            strengthScale = defaults.float(forKey: "strength_scale")
        }
        filterWeakEvents = defaults.bool(forKey: "filter_weak_events")
        dndNeverAsk = defaults.bool(forKey: "dnd_never_ask")
        capabilities = detectCapabilities()
        hapticPlayer = HapticPlayer(capabilities: capabilities)
        try? hapticPlayer.setupEngine()
        startDiscovery()
    }

    private func startDiscovery() {
        let d = Discovery { [weak self] endpoint, name in
            self?.connectTo(endpoint: endpoint, name: name)
        }
        d.start()
        discovery = d
    }

    func connectTo(endpoint: NWEndpoint, name: String) {
        reconnectTask?.cancel()
        connectTask?.cancel()
        connectionStatus = .connecting(name: name)
        clockOffsetMs = nil
        lastSyncMediaT = nil

        discovery?.stop()
        syncChannel?.close();         syncChannel    = nil
        controlChannel?.disconnect(); controlChannel = nil
        currentTimeline = nil

        lastEndpoint = endpoint
        lastName     = name

        connectTask = Task { [weak self] in
            guard let self else { return }
            let sync = SyncChannel()
            sync.onSyncPulse = { [weak self] mediaT, serverNs, rate in
                self?.mediaClock.syncAnchor(mediaT: mediaT, serverNs: serverNs, rate: rate)
                self?.lastSyncMediaT = mediaT
            }
            await sync.start()
            guard !Task.isCancelled else { sync.close(); return }
            syncChannel = sync

            let cs = ClockSync()
            clockSync = cs

            let ch = ControlChannel(endpoint: endpoint, udpPort: sync.port, capabilities: capabilities)

            ch.onConnected = { [weak self] resolvedAddress in
                guard let self else { return }
                let displayName = resolvedAddress.isEmpty ? name : resolvedAddress
                connectionStatus = .connected(name: displayName)
                reconnectDelay = reconnectDelayMin
                Task { [weak self] in
                    guard let self else { return }
                    let offset = await cs.sync(send: { [weak ch] msg in ch?.send(msg) })
                    mediaClock.setOffset(offset)
                    clockOffsetMs = offset / 1_000_000
                }
            }

            ch.onTimeResp = { [weak self] t0, ts, t1 in
                self?.clockSync?.onTimeResp(t0: t0, tServer: ts, t1: t1)
            }

            ch.onTimeline = { [weak self] data in
                guard let self else { return }
                let tl = Timeline.parse(data)
                currentTimeline = tl
                eventCount = tl.events.count
            }

            ch.onPlay = { [weak self] t, serverNs, rate in
                guard let self else { return }
                mediaClock.syncAnchor(mediaT: t, serverNs: serverNs, rate: rate)
                if let tl = currentTimeline {
                    scheduler.start(timeline: tl, mediaClock: mediaClock, player: hapticPlayer,
                                    strengthScale: strengthScale, minIntensity: effectiveMinIntensity)
                }
            }

            ch.onPause = { [weak self] t, serverNs in
                guard let self else { return }
                mediaClock.syncAnchor(mediaT: t, serverNs: serverNs, rate: 0.0)
                scheduler.stop()
            }

            ch.onSeek = { [weak self] t, serverNs in
                guard let self else { return }
                mediaClock.syncAnchor(mediaT: t, serverNs: serverNs, rate: mediaClock.rate)
                if mediaClock.isPlaying, let tl = currentTimeline {
                    scheduler.start(timeline: tl, mediaClock: mediaClock, player: hapticPlayer,
                                    strengthScale: strengthScale, minIntensity: effectiveMinIntensity)
                }
            }

            ch.onRate = { [weak self] rate, serverNs in
                guard let self else { return }
                mediaClock.syncAnchor(mediaT: mediaClock.mediaTime(), serverNs: serverNs, rate: rate)
                if mediaClock.isPlaying, let tl = currentTimeline {
                    scheduler.start(timeline: tl, mediaClock: mediaClock, player: hapticPlayer,
                                    strengthScale: strengthScale, minIntensity: effectiveMinIntensity)
                }
            }

            ch.onDisconnected = { [weak self] in
                guard let self else { return }
                scheduler.stop()
                syncChannel?.close(); syncChannel = nil
                currentTimeline = nil
                connectionStatus = .reconnecting(name: name)
                scheduleReconnect()
            }

            ch.connect()
            controlChannel = ch
        }
    }

    private func scheduleReconnect() {
        startDiscovery()

        guard let endpoint = lastEndpoint else { return }
        let delay = reconnectDelay
        reconnectDelay = min(reconnectDelay * 2, reconnectDelayMax)

        reconnectTask?.cancel()
        reconnectTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled, let self else { return }
            if case .reconnecting = connectionStatus {
                connectTo(endpoint: endpoint, name: lastName)
            }
        }
    }

    func handleBecomeActive() {
        if !dndNeverAsk { showDNDPrompt = true }
        reconnectDelay = reconnectDelayMin
        if case .connected   = connectionStatus { return }
        if case .connecting  = connectionStatus { return }
        scheduleReconnect()
    }

    func handleResignActive() {
        reconnectTask?.cancel()
        connectTask?.cancel()
        scheduler.stop()
        syncChannel?.close();         syncChannel    = nil
        controlChannel?.disconnect(); controlChannel = nil
        discovery?.stop();            discovery      = nil
        connectionStatus = .searching
    }

    func runTestTimeline() {
        let events: [HapticEvent] = [
            HapticEvent(time: 0.0, intensity: 0.8, visionType: "strike"),
            HapticEvent(time: 0.4, intensity: 0.6, visionType: "bounce"),
            HapticEvent(time: 0.8, intensity: 0.9, visionType: "strike"),
            HapticEvent(time: 1.2, intensity: 0.5, visionType: nil),
            HapticEvent(time: 1.6, intensity: 0.7, visionType: "bounce"),
            HapticEvent(time: 2.0, intensity: 1.0, visionType: "strike"),
        ]
        let tl = Timeline(events: events)
        mediaClock.syncAnchor(mediaT: 0.0, serverNs: nanoTime(), rate: 1.0)
        scheduler.start(timeline: tl, mediaClock: mediaClock, player: hapticPlayer,
                        strengthScale: strengthScale, minIntensity: effectiveMinIntensity)
    }
}
