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
