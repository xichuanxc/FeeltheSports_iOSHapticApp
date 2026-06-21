import CoreHaptics
import UIKit

enum HapticTier { case coreHaptics, uiImpact, none }

struct HapticCapabilities {
    let tier: HapticTier
    let supportsHaptics: Bool
}

func detectCapabilities() -> HapticCapabilities {
    let supports = CHHapticEngine.capabilitiesForHardware().supportsHaptics
    let tier: HapticTier = supports ? .coreHaptics
        : UIDevice.current.model.hasPrefix("iPhone") ? .uiImpact
        : .none
    return HapticCapabilities(tier: tier, supportsHaptics: supports)
}

nonisolated func supportedPrimitiveNames(_ cap: HapticCapabilities) -> [String] {
    guard cap.supportsHaptics else { return [] }
    return ["CLICK", "TICK", "LOW_TICK", "THUD"]
}
