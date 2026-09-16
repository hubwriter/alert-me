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

    @Test
    func deletingAlertCancelsItsPendingFallbackNotification() async throws {
        let container = try ModelContainer(
            for: AlertDefinition.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let calendar = Calendar.current
        let proposedDate = Date().addingTimeInterval(3_600)
        let scheduledDate = try #require(
            calendar.date(
                from: calendar.dateComponents(
                    [.year, .month, .day, .hour, .minute],
                    from: proposedDate
                )
            )
        )
        let definition = AlertDefinition(
            message: "Future alert",
            recurrence: .oneTime,
            oneTimeDate: scheduledDate,
            startDate: scheduledDate,
            hour: calendar.component(.hour, from: scheduledDate),
            minute: calendar.component(.minute, from: scheduledDate),
            weekdayMask: 0,
            monthDay: 1,
            month: 1
        )
        context.insert(definition)
        try context.save()

        let scheduler = RefreshTestNotificationScheduler()
        scheduler.status = .authorized
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

        await state.refreshAuthorizationAfterReturningFromSettings()
        let storedDefinition = try #require(state.definitions.first)
        let occurrence = try #require(storedDefinition.nextOccurrenceAt)
        let expectedIdentifier = "alert.\(storedDefinition.id.uuidString).\(Int(occurrence.timeIntervalSince1970))"

        state.delete(storedDefinition)
        await waitUntil {
            scheduler.removedPendingIdentifiers.contains(expectedIdentifier)
        }

        #expect(scheduler.removedPendingIdentifiers.contains(expectedIdentifier))
    }

    private func waitUntil(
        _ condition: @escaping @MainActor () -> Bool
    ) async {
        for _ in 0..<100 where !condition() {
            try? await Task.sleep(for: .milliseconds(10))
        }
    }
}

@MainActor
private final class RefreshTestNotificationScheduler: NotificationScheduling {
    var status: UNAuthorizationStatus = .denied
    var replaceCallCount = 0
    var removedPendingIdentifiers: [String] = []

    func authorizationStatus() async -> UNAuthorizationStatus {
        status
    }

    func requestAuthorization() async throws -> Bool {
        status.allowsAlertMeNotifications
    }

    func replaceManagedNotifications(with descriptors: [NotificationDescriptor]) async throws {
        replaceCallCount += 1
    }

    func removePendingNotification(identifier: String) async {
        removedPendingIdentifiers.append(identifier)
    }
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
