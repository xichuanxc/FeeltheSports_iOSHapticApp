import SwiftUI

struct SimpleSettingsView: View {
    @Environment(AppState.self) private var state

    private var presetIndex: Int {
        if abs(state.strengthScale - 0.5) < 0.001 { return 0 }
        if abs(state.strengthScale - 1.0) < 0.001 { return 1 }
        if abs(state.strengthScale - 1.5) < 0.001 { return 2 }
        return -1
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                vibrationCard
            }
            .padding()
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(destination: AdvancedSettingsView()) {
                    Text("Advanced")
                        .font(.subheadline)
                }
            }
        }
    }

    // MARK: Vibration Level

    private var vibrationCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Vibration Level")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Set the vibration level.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Picker("Vibration Level", selection: presetBinding) {
                Text("Low").tag(0)
                Text("Medium").tag(1)
                Text("High").tag(2)
            }
            .pickerStyle(.segmented)

            if presetIndex == -1 {
                Text("Current: \(String(format: "%.2f", state.strengthScale))×")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            Button("Test Preset Vibration") {
                state.hapticPlayer.play(visionType: "strike",
                                        intensity: min(state.strengthScale, 1.0))
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var presetBinding: Binding<Int> {
        Binding(
            get: { presetIndex == -1 ? 1 : presetIndex },
            set: { idx in
                switch idx {
                case 0: state.strengthScale = 0.5
                case 1: state.strengthScale = 1.0
                case 2: state.strengthScale = 1.5
                default: break
                }
            }
        )
    }
}

#Preview {
    NavigationStack {
        SimpleSettingsView()
            .environment(AppState())
    }
}
