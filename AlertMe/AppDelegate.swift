import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        let center = NotificationCenter.default
        [
            NSWindow.didBecomeKeyNotification,
            NSWindow.didResignKeyNotification,
            NSWindow.didBecomeMainNotification,
            NSWindow.didResignMainNotification,
            NSWindow.didMiniaturizeNotification,
            NSWindow.didDeminiaturizeNotification,
            NSWindow.willCloseNotification,
        ].forEach {
            center.addObserver(
                self,
                selector: #selector(windowVisibilityDidChange),
                name: $0,
                object: nil
            )
        }
        scheduleActivationPolicyUpdate()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    @objc
    private func windowVisibilityDidChange(_ notification: Notification) {
        scheduleActivationPolicyUpdate()
    }

    private func scheduleActivationPolicyUpdate() {
        Task { @MainActor in
            await Task.yield()
            updateActivationPolicy()
        }
    }

    private func updateActivationPolicy() {
        let application = NSApplication.shared
        let hasVisibleAppWindow = application.windows.contains {
            $0.isVisible && $0.canBecomeMain
        }
        let isUITesting = ProcessInfo.processInfo.arguments.contains("--ui-testing")
        application.setActivationPolicy(
            AppActivationPolicy.policy(
                hasVisibleAppWindow: hasVisibleAppWindow,
                isUITesting: isUITesting
            )
        )
    }
}

enum AppActivationPolicy {
    static func policy(
        hasVisibleAppWindow: Bool,
        isUITesting: Bool
    ) -> NSApplication.ActivationPolicy {
        hasVisibleAppWindow || isUITesting ? .regular : .accessory
    }

    @MainActor
    static func prepareToShowWindow() {
        NSApplication.shared.setActivationPolicy(.regular)
    }
}
