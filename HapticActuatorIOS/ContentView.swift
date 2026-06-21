import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var state = state
        ScrollView {
            VStack(spacing: 16) {
                statusCard
                diagnosticsCard
                controlsCard
                testCard
            }
            .padding()
        }
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }

    // MARK: Status card

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Connection")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 10) {
                Circle()
                    .fill(statusDotColor)
                    .frame(width: 10, height: 10)
                Text(statusLabel)
                    .font(.headline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(statusBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var statusLabel: String {
        switch state.connectionStatus {
        case .searching:              return "Searching…"
        case .connecting(let n):      return "Connecting to \(n)"
        case .reconnecting(let n):    return "Reconnecting to \(n)"
        case .connected(let n):       return n
        }
    }

    private var statusDotColor: Color {
        switch state.connectionStatus {
        case .searching:     return Color(.systemGray)
        case .connecting:    return Color(.systemYellow)
        case .reconnecting:  return Color(.systemRed)
        case .connected:     return Color(.systemGreen)
        }
    }

    private var statusBackground: Color {
        switch state.connectionStatus {
        case .searching:     return Color(.systemGray5)
        case .connecting:    return Color(.systemYellow).opacity(0.2)
        case .reconnecting:  return Color(.systemRed).opacity(0.2)
        case .connected:     return Color(.systemGreen).opacity(0.2)
        }
    }

    // MARK: Diagnostics

    private var diagnosticsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Diagnostics")
                .font(.caption)
                .foregroundStyle(.secondary)
            diagnosticRow("Haptic tier",     state.capabilities.tier.label)
            diagnosticRow("Clock offset",    state.clockOffsetMs.map { "\($0) ms" } ?? "—")
            diagnosticRow("Events loaded",   state.eventCount.map { "\($0)" } ?? "—")
            diagnosticRow("Last sync",       state.lastSyncMediaT.map { String(format: "%.3f s", $0) } ?? "—")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func diagnosticRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontDesign(.monospaced)
        }
        .font(.caption)
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

    // MARK: Test buttons

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

private extension HapticTier {
    var label: String {
        switch self {
        case .coreHaptics: return "Core Haptics"
        case .uiImpact:    return "UIImpact"
        case .none:        return "None"
        }
    }
}

#Preview {
    ContentView()
        .environment(AppState())
}
