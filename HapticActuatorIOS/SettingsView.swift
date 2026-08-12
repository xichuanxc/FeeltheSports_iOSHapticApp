import SwiftUI

struct AdvancedSettingsView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var state = state
        ScrollView {
            VStack(spacing: 16) {
                diagnosticsCard
                strengthCard
                minIntensityCard
                testCard
            }
            .padding()
        }
        .navigationTitle("Advanced")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontDesign(.monospaced)
        }
        .font(.caption)
    }

    // MARK: Diagnostics

    private var diagnosticsCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Diagnostics")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(clockAndTimelineText)
                .font(.caption.monospacedDigit())
            Text(syncText)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var clockAndTimelineText: String {
        let clock    = state.clockOffsetMs.map { "\($0 >= 0 ? "+" : "")\($0) ms" } ?? "—"
        let timeline = state.eventCount.map { "\($0) events" } ?? "—"
        return "\(clock)  ·  \(timeline)"
    }

    private var syncText: String {
        state.lastSyncMediaT.map { String(format: "Sync %.3f s", $0) } ?? "No sync yet"
    }

    // MARK: Strength

    private var strengthCard: some View {
        @Bindable var state = state
        return VStack(alignment: .leading, spacing: 8) {
            Text("Haptic Strength")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Text("0.5×").font(.caption2).foregroundStyle(.secondary)
                Slider(value: $state.strengthScale, in: 0.5...1.5, step: 0.05)
                Text("1.5×").font(.caption2).foregroundStyle(.secondary)
            }
            Text("\(String(format: "%.2f", state.strengthScale))×")
                .font(.caption)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: Min Intensity

    private var minIntensityCard: some View {
        @Bindable var state = state
        return VStack(alignment: .leading, spacing: 8) {
            Text("Min Intensity")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Text("0.0").font(.caption2).foregroundStyle(.secondary)
                Slider(value: $state.minIntensity, in: 0.0...0.5, step: 0.01)
                Text("0.5").font(.caption2).foregroundStyle(.secondary)
            }
            Text("Drop events below \(String(format: "%.2f", state.minIntensity))")
                .font(.caption)
                .frame(maxWidth: .infinity, alignment: .center)
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
            HStack(spacing: 12) {
                Button("Lightest Hit") {
                    state.hapticPlayer.play(visionType: "strike", intensity: 0.1)
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
                Button("Strongest Hit") {
                    state.hapticPlayer.play(visionType: "strike", intensity: 1.0)
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

extension HapticTier {
    var label: String {
        switch self {
        case .coreHaptics: return "Composition (Tier 1)"
        case .uiImpact:    return "Amplitude (Tier 2)"
        case .none:        return "Basic (Tier 3)"
        }
    }
}

#Preview {
    NavigationStack {
        AdvancedSettingsView()
            .environment(AppState())
    }
}
