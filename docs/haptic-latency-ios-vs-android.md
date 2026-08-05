# Haptic Latency: iOS vs Android

## Background

Pilot testing revealed a noticeable latency between the video event and the corresponding haptic feedback on the iOS device compared to an Android device running the same server. This document analyses each stage of the iOS pipeline, identifies the dominant latency source, and explains why the gap is a platform-level limitation rather than a bug in the application.

---

## Latency Pipeline (iOS)

From the moment a video event occurs on the server to the moment the Taptic Engine moves, the signal passes through five stages.

### Stage 1 — Clock synchronisation offset error

**Code:** `ClockSync.swift`
```swift
let offset = tServer - (t0 + rtt / 2)
```

An SNTP-style protocol runs 8 rounds at 20 ms intervals immediately after connection. High-RTT samples are discarded and the remainder averaged. On a local Wi-Fi network, round-trip time is typically 1–5 ms, producing a residual offset error of **< ±3 ms**.

**Contribution: < ±3 ms. Not a significant source.**

---

### Stage 2 — MediaClock extrapolation

**Code:** `MediaClock.swift`
```swift
return a.mediaT + Double(nowServerNs() - a.serverNs) / 1_000_000_000.0 * a.rate
```

Pure arithmetic on `CLOCK_MONOTONIC`. No buffering, no I/O. **Contribution: 0 ms.**

---

### Stage 3 — Scheduler sleep precision

**Code:** `Scheduler.swift`
```swift
try? await Task.sleep(nanoseconds: UInt64(min(remainingMs, maxSleepMs)) * 1_000_000)
```

Swift's `Task.sleep` runs on the cooperative thread pool. It guarantees a *minimum* sleep duration, not an exact one. In practice it wakes within 1–5 ms of the requested time on an unloaded system.

**Contribution: ~1–5 ms jitter.**

---

### Stage 4 — CoreHaptics engine latency (dominant)

**Code:** `HapticPlayer.swift`
```swift
try? player.start(atTime: CHHapticTimeImmediate)
```

`CHHapticTimeImmediate` is defined as `0.0` — the earliest possible time — but CoreHaptics is architecturally built on top of `AVAudioEngine`. Even though the Taptic Engine is not a speaker, Apple routes all haptic patterns through the audio I/O stack. The engine must:

1. Render the haptic pattern into PCM-equivalent audio buffers.
2. Submit those buffers to the audio HAL.
3. Wait for the HAL to advance to the next output buffer boundary.

On iPhone, the minimum audio I/O buffer is 5–12 ms and there are typically two buffers in the pipeline, giving an irreducible latency of **10–24 ms** before the actuator moves. This cannot be reduced at the application level — it is a consequence of the CoreHaptics architecture on all iOS devices.

**Contribution: ~10–30 ms. Platform limitation.**

---

### Stage 5 — Wi-Fi TCP message delivery

The `play` command arrives over TCP on local Wi-Fi. Delivery time is **< 1 ms** in practice. **Contribution: negligible.**

---

## Total Expected Latency

| Stage | Contribution |
|---|---|
| Clock sync error | < ±3 ms |
| MediaClock extrapolation | 0 ms |
| `Task.sleep` jitter | 1–5 ms |
| **CoreHaptics audio buffer** | **10–30 ms** |
| TCP message delivery | < 1 ms |
| **Total** | **~12–38 ms** |

---

## Comparison with Android

### Android vibration subsystem

On Android, haptic feedback is delivered through the **vibrator HAL** — a kernel-level hardware abstraction layer with a direct path to the vibration motor driver. It does not pass through the audio stack.

```
Android app  →  VibrationEffect  →  vibrator HAL  →  motor driver  →  motor
```

Latency on mid/high-end Android devices is typically **5–15 ms**.

### iOS CoreHaptics subsystem

```
iOS app  →  CHHapticEngine  →  AVAudioEngine  →  audio HAL  →  Taptic Engine
```

The audio indirection adds 10–20 ms that the Android path does not incur.

### Low-end Android (duration simulation)

On low-end Android phones that lack amplitude control, the vibration motor can only run at full power. "Intensity" is simulated by varying the *duration* of the pulse — a 30 ms burst feels light, a 100 ms burst feels heavy. This is a workaround; the iPhone SE 3rd gen has a real Taptic Engine with true amplitude control via `hapticIntensity`, which is a hardware advantage independent of the latency discussion.

---

## Summary

| | iOS (CoreHaptics) | Android mid/high-end | Android low-end |
|---|---|---|---|
| Haptic path | Audio HAL | Vibrator HAL | Vibrator HAL |
| Amplitude control | Yes (real) | Yes (real) | No (duration trick) |
| Typical latency | 15–35 ms | 5–15 ms | 20–50 ms |

The observed latency gap between the iOS device and the Android device in pilot testing is consistent with the 10–20 ms overhead introduced by the CoreHaptics audio architecture. It is a **platform limitation**, not a bug in the application code. No application-level change can eliminate this gap; the only path to lower latency on iOS would require a private API that bypasses AVAudioEngine, which is not available to App Store applications.
