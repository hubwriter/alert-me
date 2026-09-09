import SwiftData
import SwiftUI

@main
struct AlertMeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState: AlertAppState

    init() {
        do {
            let isUITesting = ProcessInfo.processInfo.arguments.contains("--ui-testing")
            let configuration = ModelConfiguration(isStoredInMemoryOnly: isUITesting)
            let container = try ModelContainer(
                for: AlertDefinition.self,
                configurations: configuration
            )
            let settings = AppSettings()
            _appState = StateObject(
                wrappedValue: AlertAppState(modelContainer: container, settings: settings)
            )
        } catch {
            fatalError("Unable to create Alert Me data store: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup("Alert Me", id: "main") {
            ContentView()
                .environmentObject(appState)
                .environmentObject(appState.settings)
                .modelContainer(appState.modelContainer)
                .preferredColorScheme(appState.settings.colorMode.colorScheme)
                .task {
                    appState.start()
                }
        }
        .defaultSize(width: 900, height: 620)
        .commands {
            AlertCommands()
        }

        MenuBarExtra("Alert Me", systemImage: "alarm") {
            MenuBarView()
                .preferredColorScheme(appState.settings.colorMode.colorScheme)
        }

        Settings {
            SettingsView()
                .environmentObject(appState)
                .environmentObject(appState.settings)
                .preferredColorScheme(appState.settings.colorMode.colorScheme)
        }
    }
}

extension Notification.Name {
    static let showNewAlert = Notification.Name("showNewAlert")
}

private struct MenuBarView: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Button("Open Alert Me") {
            openWindow(id: "main")
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
        Button("Settings…") {
            openSettings()
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
        Divider()
        Button("Quit Alert Me") {
            NSApplication.shared.terminate(nil)
        }
    }
}

private struct AlertCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Alert") {
                openWindow(id: "main")
                Task { @MainActor in
                    await Task.yield()
                    NotificationCenter.default.post(name: .showNewAlert, object: nil)
                }
            }
            .keyboardShortcut("n")
        }
    }
}
