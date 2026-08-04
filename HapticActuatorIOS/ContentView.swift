import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer()
                iconSection
                Spacer().frame(height: 40)
                statusSection
                Spacer()
                uniLogoSection
                    .padding(.bottom, 32)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(statusBackground.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink(destination: AboutView()) {
                        Image(systemName: "info.circle")
                            .font(.body)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gearshape")
                            .font(.body)
                    }
                }
            }
        }
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .alert("Enable Do Not Disturb", isPresented: Binding(
            get: { state.showDNDPrompt },
            set: { if !$0 { state.dismissDNDPrompt(permanently: false) } }
        )) {
            Button("Got it") { state.dismissDNDPrompt(permanently: false) }
            Button("Don't Ask Again", role: .cancel) { state.dismissDNDPrompt(permanently: true) }
        } message: {
            Text("For the best experience, enable Do Not Disturb or a Focus mode before watching. Swipe down from the top-right corner of your screen to access Focus controls.")
        }
    }

    // MARK: Icon

    private var iconSection: some View {
        Image("HapticIcon")
            .resizable()
            .scaledToFit()
            .frame(width: 120, height: 120)
            .clipShape(RoundedRectangle(cornerRadius: 26))
            .shadow(color: .black.opacity(0.15), radius: 12, y: 6)
    }

    // MARK: Status

    private var statusSection: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Circle()
                    .fill(statusDotColor)
                    .frame(width: 8, height: 8)
                Text(statusLabel)
                    .font(.subheadline.weight(.medium))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(statusDotColor.opacity(0.12))
            .clipShape(Capsule())

            if let offset = state.clockOffsetMs {
                Text("Clock offset \(offset) ms")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var statusLabel: String {
        switch state.connectionStatus {
        case .searching:           return "Searching for Haptic Server…"
        case .connecting(let n):   return "Connecting to \(n)…"
        case .reconnecting(let n): return "Reconnecting to \(n)…"
        case .connected(let n):    return "Connected to \(n)"
        }
    }

    private var statusDotColor: Color {
        switch state.connectionStatus {
        case .searching:    return Color(hex: 0x9E9E9E)
        case .connecting:   return Color(hex: 0xFF9800)
        case .reconnecting: return Color(hex: 0xFF9800)
        case .connected:    return Color(hex: 0x4CAF50)
        }
    }

    // MARK: University logo

    private var uniLogoSection: some View {
        Image("UniLogo")
            .resizable()
            .scaledToFit()
            .frame(width: 188)
            .opacity(0.75)
    }

    private var statusBackground: Color {
        switch state.connectionStatus {
        case .searching:    return Color(.systemBackground)
        case .connecting:   return Color(hex: 0xFF9800).opacity(0.06)
        case .reconnecting: return Color(hex: 0xFF9800).opacity(0.06)
        case .connected:    return Color(hex: 0x4CAF50).opacity(0.06)
        }
    }
}

#Preview {
    ContentView()
        .environment(AppState())
}
