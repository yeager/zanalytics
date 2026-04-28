import SwiftUI

@main
struct ZAnalyticsApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .frame(minWidth: 1100, minHeight: 720)
        }
        .commands {
            CommandGroup(after: .appInfo) {
                Button("About ZAnalytics") {
                    NSApp.orderFrontStandardAboutPanel(options: [
                        .applicationName: "ZAnalytics",
                        .applicationVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
                        .credits: NSAttributedString(string: "Unofficial helper for Zscaler Analytics reporting. Not affiliated with, endorsed by, or sponsored by Zscaler.")
                    ])
                }
            }
        }

        Settings {
            SettingsView()
                .environmentObject(appState)
                .frame(width: 820, height: 640)
        }
    }
}
