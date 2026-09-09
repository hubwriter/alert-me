import SwiftUI
import UserNotifications

struct ContentView: View {
    @EnvironmentObject private var appState: AlertAppState
    @State private var editor: AlertEditorContext?

    var body: some View {
        VStack(spacing: 0) {
            if let error = appState.lastError {
                PermissionBanner(
                    title: "Alert Me could not complete that action",
                    message: error,
                    actionTitle: "Dismiss"
                ) {
                    appState.lastError = nil
                }
            }

            if appState.notificationStatus == .notDetermined {
                PermissionBanner(
                    title: "Allow notifications for backup alerts",
                    message: "Popup alerts work while Alert Me is running. Notifications provide a fallback if it is not.",
                    actionTitle: "Allow Notifications",
                    action: appState.requestNotificationAuthorization
                )
            } else if appState.notificationStatus == .denied {
                PermissionBanner(
                    title: "Notifications are turned off",
                    message: "Enable Alert Me in System Settings to receive fallback notifications.",
                    actionTitle: "Open Settings"
                ) {
                    NSWorkspace.shared.open(
                        URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension")!
                    )
                }
            }

            if appState.definitions.isEmpty {
                ContentUnavailableView {
                    Label("No alerts", systemImage: "alarm")
                } description: {
                    Text("Create a one-time or recurring alert to get started.")
                } actions: {
                    Button("Create Alert") {
                        editor = AlertEditorContext()
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("createFirstAlertButton")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                    alertSection(
                        title: "Future",
                        definitions: appState.futureDefinitions,
                        emptyMessage: "No future alerts"
                    )
                    alertSection(
                        title: "Past",
                        definitions: appState.pastDefinitions,
                        emptyMessage: "No past alerts"
                    )
                    }
                }
            }
        }
        .frame(minWidth: 760, minHeight: 520)
        .navigationTitle("Alert Me")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    editor = AlertEditorContext()
                } label: {
                    Label("New Alert", systemImage: "plus")
                }
                .accessibilityIdentifier("newAlertButton")
            }
        }
        .sheet(item: $editor) { context in
            AlertEditorView(definition: context.definition)
                .environmentObject(appState)
        }
        .onReceive(NotificationCenter.default.publisher(for: .showNewAlert)) { _ in
            editor = AlertEditorContext()
        }
    }

    @ViewBuilder
    private func alertSection(
        title: String,
        definitions: [AlertDefinition],
        emptyMessage: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)
                .padding(.top, 14)
                .padding(.bottom, 10)
                .accessibilityAddTraits(.isHeader)

            Divider()
                .padding(.horizontal, 32)

            if definitions.isEmpty {
                Text(emptyMessage)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
            } else {
                ForEach(Array(definitions.enumerated()), id: \.element.id) { index, definition in
                    AlertRow(
                        definition: definition,
                        onEdit: {
                            editor = AlertEditorContext(definition: definition)
                        },
                        onDelete: {
                            appState.delete(definition)
                        },
                        onEnabledChange: {
                            appState.setEnabled(definition, enabled: $0)
                        }
                    )
                    .padding(.horizontal, 32)
                    .padding(.vertical, 8)

                    if index < definitions.count - 1 {
                        Divider()
                            .padding(.leading, 112)
                            .padding(.trailing, 32)
                    }
                }
            }
        }
    }
}

private struct AlertEditorContext: Identifiable {
    let id = UUID()
    var definition: AlertDefinition?
}

private struct PermissionBanner: View {
    let title: String
    let message: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "bell.badge")
                .font(.title2)
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(actionTitle, action: action)
        }
        .padding()
        .background(.orange.opacity(0.08))
    }
}
