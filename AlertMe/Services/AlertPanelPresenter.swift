import AppKit
import SwiftUI

struct DueAlert: Equatable, Sendable {
    let definitionID: UUID
    let occurrence: Date
    let createdAt: Date
    let message: String
    let isSilent: Bool
}

@MainActor
protocol AlertPresenting: AnyObject {
    var onDismiss: ((DueAlert) -> Void)? { get set }
    func enqueue(_ alerts: [DueAlert]) -> Bool
    func removeQueued(definitionID: UUID)
}

@MainActor
final class AlertPanelPresenter: AlertPresenting {
    var onDismiss: ((DueAlert) -> Void)?

    private let settings: AppSettings
    private let soundRepeater: AlertSoundRepeater
    private var queue: [DueAlert] = []
    private var currentAlert: DueAlert?
    private var panel: AlertPanel?

    init(
        settings: AppSettings,
        soundRepeater: AlertSoundRepeater = AlertSoundRepeater()
    ) {
        self.settings = settings
        self.soundRepeater = soundRepeater
    }

    func enqueue(_ alerts: [DueAlert]) -> Bool {
        queue.append(contentsOf: alerts)
        queue.sort {
            ($0.occurrence, $0.createdAt, $0.definitionID.uuidString)
                < ($1.occurrence, $1.createdAt, $1.definitionID.uuidString)
        }
        presentNextIfNeeded()
        return true
    }

    func removeQueued(definitionID: UUID) {
        queue.removeAll { $0.definitionID == definitionID }
    }

    private func presentNextIfNeeded() {
        guard currentAlert == nil, !queue.isEmpty else {
            return
        }

        let alert = queue.removeFirst()
        currentAlert = alert

        let panel = AlertPanel(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 260),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = "Alert Me"
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.appearance = settings.colorMode.nsAppearance
        panel.center()
        panel.contentView = NSHostingView(
            rootView: AlertPopupView(message: alert.message) {
                [weak self] in self?.dismissCurrent()
            }
            .preferredColorScheme(settings.colorMode.colorScheme)
        )
        self.panel = panel

        NSApplication.shared.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)

        soundRepeater.start(named: settings.soundName, isSilent: alert.isSilent)
    }

    private func dismissCurrent() {
        guard let alert = currentAlert else {
            return
        }
        soundRepeater.stop()
        panel?.orderOut(nil)
        panel = nil
        currentAlert = nil
        onDismiss?(alert)
        presentNextIfNeeded()
    }
}

final class AlertPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func cancelOperation(_ sender: Any?) {}
}

private struct AlertPopupView: View {
    let message: String
    let dismiss: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "alarm.waves.left.and.right.fill")
                .font(.system(size: 42))
                .foregroundStyle(.red)
                .accessibilityHidden(true)

            ScrollView {
                Text(message)
                    .font(.title2)
                    .multilineTextAlignment(.center)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity)
            }

            Button("Dismiss", action: dismiss)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .accessibilityIdentifier("dismissAlertButton")
        }
        .padding(32)
        .frame(minWidth: 520, minHeight: 260)
    }
}
