# Haptic Event Filter and Strength Amplification

## Overview

The iOS haptic actuator receives a timeline of events from the server. Each event carries a raw intensity value in the range 0.0–1.0. Two independent controls — **strength amplification** and **event filtering** — shape which events reach the actuator and at what physical force.

---

## 1. Strength Amplification

### Purpose

The server-sent intensity values are calibrated for a neutral reference device. On any given phone, or at any given viewing distance, the user may want haptics to feel stronger or softer. The strength slider scales every event's intensity uniformly without changing which events fire.

### Implementation

**`AppState.swift`**
```swift
var strengthScale: Float = 1.5   // default 1.5×, range 0.5–3.0
```

**`Scheduler.swift`** — applied per event, per loop iteration
```swift
let scale   = strengthScale()                           // read live from closure
let scaled  = min(max(event.intensity * scale, 0), 1)  // clamp to [0, 1]
```

The closure is evaluated on every scheduler loop iteration, so moving the slider during playback takes effect on the very next event — no seek or restart required.

### Perceptibility floor

**`HapticPlayer.swift`** — applied inside the haptic engine
```swift
let raw = max(e.intensity, 0.55)
```

Any event that reaches the player is boosted to a minimum physical intensity of `0.55`. This is independent of the strength slider and exists because the Taptic Engine produces output too faint to feel through a phone case below roughly 0.4. The floor ensures that every event that passes the filter is actually perceptible.

### Value flow

```
server intensity (e.g. 0.4)
        │
        × strengthScale (e.g. 1.5)  →  scaled = 0.60
        │
        clamped to [0, 1]           →  0.60
        │
        max(·, 0.55)                →  0.60  (floor only kicks in below 0.55)
        │
        CHHapticEvent hapticIntensity = 0.60
```

---

## 2. Event Filter

### Purpose

At lower amplification settings, some events produce haptic output below the threshold of perception. Firing them wastes engine cycles and can muddy the overall texture. The filter drops events whose scaled intensity falls below a configurable threshold before they reach the haptic engine.

### Controls

| Setting | Default | Persisted |
|---|---|---|
| Filter weak events (toggle) | Off | `UserDefaults` |
| Threshold slider | 0.15 | `UserDefaults` |

The toggle is off by default because the server already applies its own filtering. The slider is only shown when the toggle is on.

### Implementation

**`AppState.swift`**
```swift
var filterWeakEvents: Bool  = false
var filterThreshold:  Float = 0.15          // range 0.05–0.50

var effectiveMinIntensity: Float {
    filterWeakEvents ? filterThreshold : 0.0
}
```

**`Scheduler.swift`** — gate applied after scaling, before the engine
```swift
let threshold = minIntensity()              // read live from closure
let scaled    = min(max(event.intensity * scale, 0), 1)
if scaled < threshold { i += 1; continue } // ← event dropped here
```

The same threshold is applied when collecting a batch of co-occurring events:
```swift
let nextScaled = min(max(next.intensity * scale, 0), 1)
if nextScaled >= threshold {
    batch.append(...)                       // only include if above threshold
}
```

Both closures are evaluated live, so changes to the toggle or slider apply to the next event without restarting the scheduler.

### Filter vs. floor: interaction

The filter and the perceptibility floor (`0.55`) are independent:

- The filter decides **whether** an event fires.
- The floor decides **how hard** it fires once it has passed the filter.

An event with scaled intensity `0.10` and threshold `0.15` is **dropped** at the filter — the floor is never reached.  
An event with scaled intensity `0.30` and threshold `0.15` **passes** the filter, then the floor raises its playback intensity to `0.55`.

---

## 3. Processing Pipeline (end to end)

```
Server timeline event
  intensity: 0.4,  visionType: "strike"
        │
        ▼
  Scheduler — per loop iteration
  ┌─────────────────────────────────────────────┐
  │  scale     = strengthScale()   // e.g. 1.5  │
  │  threshold = minIntensity()    // e.g. 0.15 │
  │  scaled    = 0.4 × 1.5 = 0.60              │
  │  0.60 ≥ 0.15  →  event passes filter        │
  └─────────────────────────────────────────────┘
        │
        ▼
  HapticPlayer.makeHapticEvent()
  ┌─────────────────────────────────────────────┐
  │  raw = max(0.60, 0.55) = 0.60               │
  │  CHHapticEvent(.hapticTransient,            │
  │    intensity: min(0.60 × 1.05, 1.0) = 0.63)│
  └─────────────────────────────────────────────┘
        │
        ▼
  CHHapticEngine → Taptic Engine actuator
```
