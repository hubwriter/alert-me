import SwiftUI
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject private var appState: AlertAppState
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Color mode", selection: $settings.colorMode) {
                    ForEach(AppColorMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Text("Alert Me uses Light mode by default.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Sound") {
                Picker("Default alert sound", selection: $settings.soundName) {
                    ForEach(settings.availableSounds, id: \.self) {
                        Text($0).tag($0)
                    }
                }

                Button("Preview Sound") {
                    settings.previewSound()
                }

                Text("This system sound is used for every alert unless that alert is set to silent.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Reliability") {
                Toggle("Open Alert Me at login", isOn: launchAtLoginBinding)
                Toggle("Show Alert Me in the Dock", isOn: showInDockBinding)
                if appState.loginItemState == .requiresApproval {
                    Text("Approval is required in System Settings > General > Login Items.")
                        .foregroundStyle(.orange)
                }
                if case let .unavailable(message) = appState.loginItemState {
                    Text(message)
                        .foregroundStyle(.red)
                }

                HStack {
                    Text("Notifications")
                    Spacer()
                    Text(notificationStatusText)
                        .foregroundStyle(.secondary)
                }

                if appState.notificationStatus == .notDetermined {
                    Button("Allow Notifications") {
                        appState.requestNotificationAuthorization()
                    }
                } else if appState.notificationStatus == .denied {
                    Button("Open Notification Settings") {
                        NSWorkspace.shared.open(
                            URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension")!
                        )
                    }
                }
            }

            Section("About alert reliability") {
                Text(
                    "Alert Me stays running after its window closes. Explicitly quitting the app prevents popup alerts until it is opened again. System notifications are a best-effort fallback."
                )
                .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 520, height: 420)
        .padding()
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { appState.loginItemState == .enabled },
            set: { enabled in
                appState.setLaunchAtLogin(enabled)
            }
        )
    }

    private var showInDockBinding: Binding<Bool> {
        Binding(
            get: { settings.showsDockIcon },
            set: { showsDockIcon in
                appState.setShowsDockIcon(showsDockIcon)
            }
        )
    }

    private var notificationStatusText: String {
        switch appState.notificationStatus {
        case .notDetermined: "Not requested"
        case .denied: "Denied"
        case .authorized: "Allowed"
        case .provisional: "Provisional"
        case .ephemeral: "Temporary"
        @unknown default: "Unknown"
        }
    }
}
