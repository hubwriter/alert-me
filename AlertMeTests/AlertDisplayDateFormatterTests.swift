import Foundation
import Testing
@testable import AlertMe

struct AlertDisplayDateFormatterTests {
    @Test
    func displaysCalendarEndDateUsingItsStoredDay() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/Los_Angeles"))
        let date = try #require(
            CalendarDate(year: 2026, month: 6, day: 16).date(in: calendar)
        )

        #expect(
            AlertDisplayDateFormatter.dateString(
                from: date,
                calendar: calendar,
                locale: Locale(identifier: "en_US")
            ) == "16 June 2026"
        )
    }

    @Test
    func formatsDayBeforeFullMonthName() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 9, day: 9))
        )

        let result = AlertDisplayDateFormatter.dateString(
            from: date,
            calendar: calendar,
            locale: Locale(identifier: "en_US")
        )

        #expect(result == "09 September 2026")
    }
}
