import CoreHaptics
import UIKit

enum HapticTier { case coreHaptics, uiImpact, none }

struct HapticCapabilities {
    let tier: HapticTier
    let supportsHaptics: Bool
    let supportsTransient: Bool
    let supportsContinuous: Bool
}

func detectCapabilities() -> HapticCapabilities {
    let hw = CHHapticEngine.capabilitiesForHardware()
    let supports = hw.supportsHaptics
    let tier: HapticTier = supports ? .coreHaptics
        : UIDevice.current.model.hasPrefix("iPhone") ? .uiImpact
        : .none
    return HapticCapabilities(
        tier: tier,
        supportsHaptics: supports,
        supportsTransient:  supports || tier == .uiImpact,
        supportsContinuous: supports
    )
}

nonisolated func supportedPrimitiveNames(_ cap: HapticCapabilities) -> [String] {
    guard cap.supportsHaptics else { return [] }
    return ["CLICK", "TICK", "LOW_TICK", "THUD"]
}
