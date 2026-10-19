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
    func missedPreviousWeekdayDoesNotMarkTodaysFutureOccurrenceAsHandled() async throws {
        let (state, scheduler, presenter) = try makeState()
        let calendar = Calendar.current
        let anchor = try #require(calendar.date(from: DateComponents(year: 2090, month: 1, day: 1)))
        let friday = try #require(calendar.nextDate(
            after: anchor,
            matching: DateComponents(hour: 12, minute: 59, weekday: 6),
            matchingPolicy: .nextTime
        ))
        let monday = try #require(calendar.date(byAdding: .day, value: 3, to: friday))
        let now = try #require(calendar.date(bySettingHour: 11, minute: 9, second: 0, of: monday))
        let definition = makeDefinition(recurrence: .daily, occurrence: friday)
        definition.hour = 12
        definition.minute = 59
        definition.endDate = nil
        definition.isWeekdaysOnly = true
        state.modelContainer.mainContext.insert(definition)
        try state.modelContainer.mainContext.save()
        await state.refreshAuthorizationAfterReturningFromSettings()

        await state.reconcile(markElapsedAsMissed: true, now: now)

        let stored = try #require(state.definitions.first)
        #expect(stored.lastOutcome == .missed)
        #expect(stored.lastHandledOccurrence == friday)
        #expect(stored.missedCount == 1)
        #expect(stored.nextOccurrenceAt == monday)
        #expect(stored.nextOccurrenceAt! > now)
        #expect(presenter.alerts.isEmpty)
        #expect(scheduler.descriptors.first?.deliveryDate == NotificationFallbackPolicy.deliveryDate(for: monday))
        #expect(state.listSections(relativeTo: now).first?.title == "Today")
        let row = AlertRow(definition: stored, onEdit: {}, onDelete: {}, onEnabledChange: { _ in })
        #expect(row.outcomeDescription(.missed) == "Last occurrence missed")

        await state.handleTimer(now: monday)

        #expect(presenter.alerts.count == 1)
        #expect(presenter.alerts.first?.occurrence == monday)
        #expect(stored.lastOutcome == .scheduled)
        #expect(stored.lastHandledOccurrence == monday)
        #expect(stored.missedCount == 1)
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
        #expect(definition.endDateCalendarDay == draft.endDateCalendarDay)

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
