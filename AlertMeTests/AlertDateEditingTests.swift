import Foundation
import Testing
@testable import AlertMe

struct AlertDateEditingTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    @Test
    func replacingDatePreservesTime() throws {
        let original = try #require(
            calendar.date(
                from: DateComponents(
                    year: 2026,
                    month: 9,
                    day: 9,
                    hour: 15,
                    minute: 45
                )
            )
        )
        let replacement = try #require(
            calendar.date(from: DateComponents(year: 2027, month: 2, day: 3))
        )

        let result = AlertDateEditing.replacingDate(
            in: original,
            with: replacement,
            calendar: calendar
        )
        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: result
        )
        #expect(components.year == 2027)
        #expect(components.month == 2)
        #expect(components.day == 3)
        #expect(components.hour == 15)
        #expect(components.minute == 45)
    }

    @Test
    func replacingTimePreservesDateAndDropsSeconds() throws {
        let original = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 9, day: 9))
        )
        let replacement = try #require(
            calendar.date(
                from: DateComponents(hour: 10, minute: 29, second: 52)
            )
        )

        let result = AlertDateEditing.replacingTime(
            in: original,
            with: replacement,
            calendar: calendar
        )
        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: result
        )
        #expect(components.year == 2026)
        #expect(components.month == 9)
        #expect(components.day == 9)
        #expect(components.hour == 10)
        #expect(components.minute == 29)
        #expect(components.second == 0)
    }
}
