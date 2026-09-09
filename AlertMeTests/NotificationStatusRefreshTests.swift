import SwiftData
import Testing
import UserNotifications
@testable import AlertMe

@MainActor
struct NotificationStatusRefreshTests {
    @Test
    func refreshesAuthorizationAndReconcilesAfterReturningFromSettings() async throws {
        let container = try ModelContainer(
            for: AlertDefinition.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let scheduler = RefreshTestNotificationScheduler()
        let state = AlertAppState(
            modelContainer: container,
            settings: AppSettings(
                defaults: try #require(UserDefaults(suiteName: UUID().uuidString)),
                availableSounds: ["Glass"]
            ),
            notificationScheduler: scheduler,
            loginItemService: RefreshTestLoginItemService(),
            presenter: RefreshTestPresenter()
        )

        scheduler.status = .authorized
        await state.refreshAuthorizationAfterReturningFromSettings()

        #expect(state.notificationStatus == .authorized)
        #expect(scheduler.replaceCallCount == 1)
    }
}

@MainActor
private final class RefreshTestNotificationScheduler: NotificationScheduling {
    var status: UNAuthorizationStatus = .denied
    var replaceCallCount = 0

    func authorizationStatus() async -> UNAuthorizationStatus {
        status
    }

    func requestAuthorization() async throws -> Bool {
        status.allowsAlertMeNotifications
    }

    func replaceManagedNotifications(with descriptors: [NotificationDescriptor]) async throws {
        replaceCallCount += 1
    }

    func removePendingNotification(identifier: String) {}
    func removeDeliveredNotification(identifier: String) {}
}

@MainActor
private struct RefreshTestLoginItemService: LoginItemServicing {
    var state: LoginItemState { .disabled }
    func setEnabled(_ enabled: Bool) throws {}
}

@MainActor
private final class RefreshTestPresenter: AlertPresenting {
    var onDismiss: ((DueAlert) -> Void)?
    func enqueue(_ alerts: [DueAlert]) -> Bool { true }
    func removeQueued(definitionID: UUID) {}
}
