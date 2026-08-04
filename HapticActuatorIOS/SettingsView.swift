import SwiftUI
import CoreHaptics
import Darwin

struct SettingsView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var state = state
        ScrollView {
            VStack(spacing: 16) {
                hardwareCard
                diagnosticsCard
                controlsCard
                testCard
            }
            .padding()
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Hardware card

    private var hardwareCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Haptic Hardware")
                .font(.caption)
                .foregroundStyle(.secondary)
            infoRow("Device",      deviceModel)
            infoRow("iOS",         UIDevice.current.systemVersion)
            infoRow("Engine",      state.capabilities.tier.label)
            infoRow("CoreHaptics", state.capabilities.supportsHaptics ? "Supported" : "Not supported")
            infoRow("Transient",   state.capabilities.supportsTransient  ? "Yes" : "No")
            infoRow("Continuous",  state.capabilities.supportsContinuous ? "Yes" : "No")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontDesign(.monospaced)
        }
        .font(.caption)
    }

    private var deviceModel: String {
        var size = 0
        sysctlbyname("hw.machine", nil, &size, nil, 0)
        var buf = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.machine", &buf, &size, nil, 0)
        let id = String(cString: buf)
        return knownModels[id] ?? id
    }

    private let knownModels: [String: String] = [
        "iPhone10,1": "iPhone 8",       "iPhone10,4": "iPhone 8",
        "iPhone10,2": "iPhone 8 Plus",  "iPhone10,5": "iPhone 8 Plus",
        "iPhone10,3": "iPhone X",       "iPhone10,6": "iPhone X",
        "iPhone11,2": "iPhone XS",      "iPhone11,4": "iPhone XS Max",
        "iPhone11,6": "iPhone XS Max",  "iPhone11,8": "iPhone XR",
        "iPhone12,1": "iPhone 11",      "iPhone12,3": "iPhone 11 Pro",
        "iPhone12,5": "iPhone 11 Pro Max",
        "iPhone13,1": "iPhone 12 mini", "iPhone13,2": "iPhone 12",
        "iPhone13,3": "iPhone 12 Pro",  "iPhone13,4": "iPhone 12 Pro Max",
        "iPhone14,4": "iPhone 13 mini", "iPhone14,5": "iPhone 13",
        "iPhone14,2": "iPhone 13 Pro",  "iPhone14,3": "iPhone 13 Pro Max",
        "iPhone14,7": "iPhone 14",      "iPhone14,8": "iPhone 14 Plus",
        "iPhone15,2": "iPhone 14 Pro",  "iPhone15,3": "iPhone 14 Pro Max",
        "iPhone15,4": "iPhone 15",      "iPhone15,5": "iPhone 15 Plus",
        "iPhone16,1": "iPhone 15 Pro",  "iPhone16,2": "iPhone 15 Pro Max",
        "iPhone17,3": "iPhone 16",      "iPhone17,4": "iPhone 16 Plus",
        "iPhone17,1": "iPhone 16 Pro",  "iPhone17,2": "iPhone 16 Pro Max",
    ]

    // MARK: Diagnostics

    private var diagnosticsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Session")
                .font(.caption)
                .foregroundStyle(.secondary)
            infoRow("Clock offset",  state.clockOffsetMs.map { "\($0) ms" } ?? "—")
            infoRow("Events loaded", state.eventCount.map { "\($0)" } ?? "—")
            infoRow("Last sync",     state.lastSyncMediaT.map { String(format: "%.3f s", $0) } ?? "—")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: Controls

    private var controlsCard: some View {
        @Bindable var state = state
        return VStack(alignment: .leading, spacing: 14) {
            Text("Controls")
                .font(.caption)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 4) {
                Text("Strength  \(String(format: "%.2f", state.strengthScale))×")
                    .font(.caption)
                Slider(value: $state.strengthScale, in: 0.5...3.0)
            }
            Toggle("Filter weak events", isOn: $state.filterWeakEvents)
                .font(.caption)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: Test

    private var testCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Test")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Test Timeline") { state.runTestTimeline() }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

extension HapticTier {
    var label: String {
        switch self {
        case .coreHaptics: return "Core Haptics"
        case .uiImpact:    return "UIImpact"
        case .none:        return "None"
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environment(AppState())
    }
}
