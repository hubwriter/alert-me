import Foundation
import SwiftData
import Testing
import UserNotifications
@testable import AlertMe

@MainActor
struct AlertEndDateLifecycleTests {
    @Test(arguments: [RecurrenceKind.daily, .weekly, .monthly, .yearly])
    func finalTriggerPresentsOnceAndRemovesFutureNotifications(recurrence: RecurrenceKind) async throws {
        let (state, scheduler, presenter) = try makeState()
        let calendar = Calendar.current
        let occurrence = try #require(calendar.date(
            from: DateComponents(year: 2090, month: 6, day: 16, hour: 9)
        ))
        let definition = makeDefinition(recurrence: recurrence, occurrence: occurrence)
        state.modelContainer.mainContext.insert(definition)
        try state.modelContainer.mainContext.save()
        await state.refreshAuthorizationAfterReturningFromSettings()

        #expect(state.definitions.first?.nextOccurrenceAt == occurrence)
        #expect(scheduler.descriptors.count == 1)

        await state.handleTimer(now: occurrence)
        await state.handleTimer(now: occurrence.addingTimeInterval(1))

        let stored = try #require(state.definitions.first)
        #expect(presenter.alerts.count == 1)
        #expect(presenter.alerts.first?.occurrence == occurrence)
        #expect(stored.lastHandledOccurrence == occurrence)
        #expect(stored.nextOccurrenceAt == nil)
        #expect(stored.lastOutcome == .scheduled)
        #expect(state.futureDefinitions(relativeTo: occurrence).isEmpty)
        #expect(state.pastDefinitions(relativeTo: occurrence).count == 1)
        #expect(scheduler.descriptors.isEmpty)
    }

    @Test
    func missedFinalTriggerDoesNotRescheduleBeyondCutoff() async throws {
        let (state, scheduler, presenter) = try makeState()
        let occurrence = try #require(Calendar.current.date(
            from: DateComponents(year: 2090, month: 6, day: 16, hour: 9)
        ))
        let definition = makeDefinition(recurrence: .daily, occurrence: occurrence)
        state.modelContainer.mainContext.insert(definition)
        try state.modelContainer.mainContext.save()
        await state.refreshAuthorizationAfterReturningFromSettings()

        await state.reconcile(markElapsedAsMissed: true, now: occurrence.addingTimeInterval(3_600))

        let stored = try #require(state.definitions.first)
        #expect(stored.lastOutcome == .missed)
        #expect(stored.missedCount == 1)
        #expect(stored.nextOccurrenceAt == nil)
        #expect(presenter.alerts.isEmpty)
        #expect(scheduler.descriptors.isEmpty)
        #expect(state.pastDefinitions(relativeTo: occurrence.addingTimeInterval(3_600)).count == 1)
    }

    @Test
    func addAndUpdatePersistOrRemoveEndDate() async throws {
        let (state, _, _) = try makeState()
        var draft = AlertDraft()
        draft.message = "Recurring alert"
        draft.recurrence = .daily
        draft.endDate = Calendar.current.startOfDay(for: draft.scheduledDate.addingTimeInterval(86_400))
        state.add(draft)

        let definition = try #require(state.definitions.first)
        #expect(definition.endDate == draft.endDate)

        draft.endDate = nil
        state.update(definition, with: draft)
        #expect(definition.endDate == nil)
        await state.reconcile(markElapsedAsMissed: true)
    }

    private func makeDefinition(recurrence: RecurrenceKind, occurrence: Date) -> AlertDefinition {
        let calendar = Calendar.current
        return AlertDefinition(
            message: "Final alert",
            recurrence: recurrence,
            oneTimeDate: nil,
            startDate: occurrence,
            hour: 9,
            minute: 0,
            weekdayMask: WeekdayMask.value(for: calendar.component(.weekday, from: occurrence)),
            monthDay: 16,
            month: 6,
            endDate: calendar.startOfDay(for: occurrence)
        )
    }

    private func makeState() throws -> (AlertAppState, EndDateTestScheduler, EndDateTestPresenter) {
        let container = try ModelContainer(
            for: AlertDefinition.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let scheduler = EndDateTestScheduler()
        let presenter = EndDateTestPresenter()
        let state = AlertAppState(
            modelContainer: container,
            settings: AppSettings(
                defaults: try #require(UserDefaults(suiteName: UUID().uuidString)),
                availableSounds: ["Glass"]
            ),
            notificationScheduler: scheduler,
            loginItemService: EndDateTestLoginItemService(),
            presenter: presenter
        )
        return (state, scheduler, presenter)
    }
}

@MainActor
private final class EndDateTestScheduler: NotificationScheduling {
    var descriptors: [NotificationDescriptor] = []
    func authorizationStatus() async -> UNAuthorizationStatus { .authorized }
    func requestAuthorization() async throws -> Bool { true }
    func replaceManagedNotifications(with descriptors: [NotificationDescriptor]) async throws {
        self.descriptors = descriptors
    }
    func removePendingNotification(identifier: String) async {}
    func removeDeliveredNotification(identifier: String) {}
}

@MainActor
private struct EndDateTestLoginItemService: LoginItemServicing {
    var state: LoginItemState { .disabled }
    func setEnabled(_ enabled: Bool) throws {}
}

@MainActor
private final class EndDateTestPresenter: AlertPresenting {
    var onDismiss: ((DueAlert) -> Void)?
    var alerts: [DueAlert] = []
    func enqueue(_ alerts: [DueAlert]) -> Bool {
        self.alerts.append(contentsOf: alerts)
        return true
    }
    func removeQueued(definitionID: UUID) {}
}
