import Foundation
import Testing
@testable import AlertMe

struct AlertDraftTests {
    @Test
    func weeklyDefaultUsesCurrentWeekdayWhenDefaultTimeCrossesMidnight() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let sunday = try #require(
            calendar.date(
                from: DateComponents(
                    year: 2026,
                    month: 9,
                    day: 13,
                    hour: 23,
                    minute: 58
                )
            )
        )

        let draft = AlertDraft(now: sunday, calendar: calendar)

        #expect(draft.weekdayMask == WeekdayMask.value(for: 1))
        #expect(calendar.component(.weekday, from: draft.scheduledDate) == 2)
    }

    @Test
    func snapshotDropsSecondsFromSelectedTime() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let selectedDate = try #require(
            calendar.date(
                from: DateComponents(
                    year: 2026,
                    month: 9,
                    day: 9,
                    hour: 10,
                    minute: 29,
                    second: 52
                )
            )
        )
        var draft = AlertDraft(now: selectedDate, calendar: calendar)
        draft.scheduledDate = selectedDate

        let snapshot = draft.snapshot(calendar: calendar)

        #expect(snapshot.oneTimeDate.map { calendar.component(.second, from: $0) } == 0)
        #expect(calendar.component(.second, from: snapshot.startDate) == 0)
    }
}
