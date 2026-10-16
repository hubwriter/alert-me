import Foundation
import Testing
@testable import AlertMe

@MainActor
struct AlertAppStateSortingTests {
    @Test
    func futureAlertsAreOrderedByClosestNextOccurrence() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let yearly = makeDefinition(
            message: "Yearly",
            recurrence: .yearly,
            date: now.addingTimeInterval(-86_400)
        )
        yearly.nextOccurrenceAt = now.addingTimeInterval(31_449_600)
        let later = makeDefinition(
            message: "Later",
            recurrence: .oneTime,
            date: now.addingTimeInterval(7_200)
        )
        let sooner = makeDefinition(
            message: "Sooner",
            recurrence: .oneTime,
            date: now.addingTimeInterval(3_600)
        )

        let ordered = AlertAppState.futureDefinitions(
            from: [yearly, later, sooner],
            relativeTo: now
        )

        #expect(ordered.map(\.message) == ["Sooner", "Later", "Yearly"])
    }

    @Test
    func pastAlertsAreOrderedByClosestPreviousOccurrence() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let older = makeDefinition(
            message: "Older",
            recurrence: .oneTime,
            date: now.addingTimeInterval(-7_200)
        )
        let recent = makeDefinition(
            message: "Recent",
            recurrence: .oneTime,
            date: now.addingTimeInterval(-3_600)
        )

        let ordered = AlertAppState.pastDefinitions(
            from: [older, recent],
            relativeTo: now
        )

        #expect(ordered.map(\.message) == ["Recent", "Older"])
    }

    @Test
    func completedRecurrenceMovesToPastBeforeCutoffDayPasses() throws {
        let calendar = Calendar.current
        let occurrence = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 6, day: 10, hour: 9))
        )
        let definition = makeDefinition(message: "Monthly", recurrence: .monthly, date: occurrence)
        definition.hour = 9
        definition.monthDay = 10
        definition.endDate = calendar.date(from: DateComponents(year: 2026, month: 6, day: 30))
        definition.nextOccurrenceAt = occurrence

        let before = occurrence.addingTimeInterval(-1)
        #expect(AlertAppState.futureDefinitions(from: [definition], relativeTo: before).count == 1)
        #expect(AlertAppState.pastDefinitions(from: [definition], relativeTo: before).isEmpty)

        definition.lastHandledOccurrence = occurrence
        definition.nextOccurrenceAt = nil
        let after = occurrence.addingTimeInterval(1)
        #expect(AlertAppState.futureDefinitions(from: [definition], relativeTo: after).isEmpty)
        #expect(AlertAppState.pastDefinitions(from: [definition], relativeTo: after).count == 1)
    }

    @Test
    func completedRecurrencesSortByFinalTriggerAndUnlimitedAlertsStayFuture() throws {
        let calendar = Calendar.current
        let recentDate = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 6, day: 10, hour: 9))
        )
        let olderDate = recentDate.addingTimeInterval(-86_400)
        let recent = makeDefinition(message: "Recent", recurrence: .daily, date: recentDate)
        let older = makeDefinition(message: "Older", recurrence: .daily, date: olderDate)
        let unlimited = makeDefinition(message: "Unlimited", recurrence: .daily, date: olderDate)
        let disabled = makeDefinition(message: "Disabled", recurrence: .daily, date: olderDate)
        for definition in [recent, older, disabled] {
            definition.hour = 9
            definition.endDate = calendar.startOfDay(for: definition.startDate)
        }
        recent.lastHandledOccurrence = recentDate
        older.lastHandledOccurrence = olderDate
        disabled.isEnabled = false
        let now = recentDate.addingTimeInterval(1)

        #expect(AlertAppState.pastDefinitions(
            from: [older, recent], relativeTo: now
        ).map(\.message) == ["Recent", "Older"])
        #expect(AlertAppState.futureDefinitions(from: [unlimited], relativeTo: now).count == 1)
        #expect(AlertAppState.pastDefinitions(from: [disabled], relativeTo: now).count == 1)
    }

    private func makeDefinition(
        message: String,
        recurrence: RecurrenceKind,
        date: Date
    ) -> AlertDefinition {
        AlertDefinition(
            message: message,
            recurrence: recurrence,
            oneTimeDate: recurrence == .oneTime ? date : nil,
            startDate: date,
            hour: 0,
            minute: 0,
            weekdayMask: 0,
            monthDay: 1,
            month: 1
        )
    }
}
