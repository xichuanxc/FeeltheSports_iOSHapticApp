import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var state = state
        ScrollView {
            VStack(spacing: 16) {
                diagnosticsCard
                controlsCard
                testCard
            }
            .padding()
        }
        .navigationTitle("Settings")
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
            if state.filterWeakEvents {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Drop events below \(String(format: "%.2f", state.filterThreshold))×")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Slider(value: $state.filterThreshold, in: 0.05...0.50, step: 0.01)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .animation(.easeInOut(duration: 0.2), value: state.filterWeakEvents)
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
