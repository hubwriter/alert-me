import Foundation
import Testing
@testable import AlertMe

@MainActor
struct AlertRowTests {
    @Test(arguments: RecurrenceKind.allCases)
    func outcomeLabelsDistinguishRecurringHistoryFromOneTimeResults(recurrence: RecurrenceKind) {
        let definition = AlertDefinition(
            message: "Test alert",
            recurrence: recurrence,
            oneTimeDate: nil,
            startDate: Date(),
            hour: 12,
            minute: 59,
            weekdayMask: WeekdayMask.value(for: 2),
            monthDay: 1,
            month: 1
        )
        let row = AlertRow(definition: definition, onEdit: {}, onDelete: {}, onEnabledChange: { _ in })

        #expect(row.outcomeDescription(.scheduled) == "Alerting")
        #expect(row.outcomeDescription(.missed) == (
            recurrence == .oneTime ? "Missed" : "Last occurrence missed"
        ))
        #expect(row.outcomeDescription(.dismissed) == (
            recurrence == .oneTime ? "Dismissed" : "Last occurrence dismissed"
        ))
    }
}
