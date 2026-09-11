import Foundation
import Testing
@testable import AlertMe

@MainActor
struct AlertEditorDateFormatterTests {
    @Test
    func formatsSelectedDateAsWeekday() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US")
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let wednesday = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 9, day: 30))
        )
        let thursday = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 10, day: 1))
        )

        #expect(AlertDateTimeControls.weekdayName(for: wednesday, calendar: calendar) == "Wednesday")
        #expect(AlertDateTimeControls.weekdayName(for: thursday, calendar: calendar) == "Thursday")
    }

    @Test
    func formatsEditorDateDayFirst() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 9, day: 30))
        )
        AlertDateTimeControls.dateFormatter.timeZone = calendar.timeZone

        #expect(AlertDateTimeControls.dateFormatter.string(from: date) == "30/09/2026")
    }
}
