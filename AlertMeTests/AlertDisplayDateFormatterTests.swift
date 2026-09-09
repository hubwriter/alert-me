import Foundation
import Testing
@testable import AlertMe

struct AlertDisplayDateFormatterTests {
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
