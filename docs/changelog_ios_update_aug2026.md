# iOS Update Notes — 10 Aug 2026

Changes since the initial iOS porting guide. Covers everything from the Settings redesign onwards.

---

## 1. Settings split into two screens

The single Settings screen is now two screens. The ⚙ button on Main opens **Simple Settings**; a button inside it opens **Advanced Settings & Diagnostics**.

Screen routing priority (add `showAdvanced` flag):

```
showSettings && showAdvanced  →  Advanced Settings & Diagnostics
showSettings                  →  Simple Settings
showAbout                     →  About
else                          →  Main
```

---

## 2. Simple Settings (new)

- **Segmented control** — single-choice, three options:

  | Label  | `strengthScale` |
  |--------|-----------------|
  | Low    | 0.5             |
  | Medium | 1.0             |
  | High   | 1.5             |

- Description text below heading: *"Set the vibration level."*
- If stored value doesn't match any preset (set via Advanced slider), show hint: `"Current: X.XX×"`
- **"Test Preset Vibration"** button — plays a "strike" at the current `strengthScale` (clamped to 0–1)
- **"Advanced"** button/toolbar item → sets `showAdvanced = true`

---

## 3. Advanced Settings & Diagnostics (updated)

### Diagnostics — compact, 2 lines
```
"{clockText}  ·  {timelineText}"
"{udpText}"
```

### Haptic Strength slider
- Range: **0.5 – 1.5**, step **0.05×** (snap to 21 positions)
- Default: **1.0**
- UserDefaults key: `strength_scale`

### Test buttons — two in one row
| Label        | Intensity | Position |
|--------------|-----------|----------|
| Lightest Hit | 0.1       | Left     |
| Strongest Hit | 1.0      | Right    |

These bypass `strengthScale` and use literal intensity values.

### Min Intensity slider
- Range: **0.0 – 0.5**, default **0.0**
- UserDefaults key: `min_intensity`

### Basic Motor Duration range slider — **Tier 3 only**, hidden otherwise
- Overall range: **10 – 500 ms**, step **10 ms**, minimum gap between thumbs **10 ms**
- Defaults: min **20 ms**, max **60 ms**
- UserDefaults keys: `basic_min_ms`, `basic_max_ms`
- Applied to `HapticPlayer.basicMinDurationMs` / `basicMaxDurationMs`
- iOS has no built-in two-thumb slider — use a custom component

---

## 4. About screen updates

### App identity lockup
Horizontal row at the top: `haptic_icon` at **48 pt** on the left, bold app name (`headlineMedium`) on the right, 12 pt gap, vertically centred.

### Version row — merged with build date
```
"1.0.1 · 10 Aug 2026"
```
Read version dynamically from bundle; hardcode the build date string.

### Device info section (new)
| Label   | Example value          | Source                            |
|---------|------------------------|-----------------------------------|
| iOS     | `iOS 17.5`             | `UIDevice.current.systemVersion`  |
| Haptics | `Composition (Tier 1)` | Result of tier detection          |

Tier label strings: `"Composition (Tier 1)"` / `"Amplitude (Tier 2)"` / `"Basic (Tier 3)"`

---

## 5. First-run defaults

On first launch, if `strength_scale` is absent from UserDefaults, write all four defaults at once:

```swift
if UserDefaults.standard.object(forKey: "strength_scale") == nil {
    UserDefaults.standard.set(Float(1.0), forKey: "strength_scale")
    UserDefaults.standard.set(Float(0.0), forKey: "min_intensity")
    UserDefaults.standard.set(20,         forKey: "basic_min_ms")
    UserDefaults.standard.set(60,         forKey: "basic_max_ms")
}
```

This ensures Simple Settings shows **Medium** selected on the very first run.

---

## 6. Scheduler & HapticPlayer

- `Scheduler.minIntensity` default corrected to **0.0** (was 0.15).
- Tier 3 duration formula now uses configurable range:
  ```
  durationMs = basicMinDurationMs + scale × (basicMaxDurationMs − basicMinDurationMs)
  ```
  Default: `20 + scale × 40` → 20 ms (quiet) … 60 ms (full).
