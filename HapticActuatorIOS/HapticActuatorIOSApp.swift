import SwiftUI

@main
struct HapticActuatorIOSApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .onReceive(
                    NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
                ) { _ in
                    appState.handleBecomeActive()
                }
                .onReceive(
                    NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
                ) { _ in
                    appState.handleResignActive()
                }
        }
    }
}
