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

    @Test
    func dayWrapsWithinCurrentMonth() throws {
        let first = try date(year: 2026, month: 9, day: 1, hour: 14, minute: 30)
        let last = try date(year: 2026, month: 9, day: 30, hour: 14, minute: 30)

        #expect(
            components(
                AlertDateEditing.stepping(.day, by: -1, in: first, calendar: calendar)
            ).day == 30
        )
        #expect(
            components(
                AlertDateEditing.stepping(.day, by: 1, in: last, calendar: calendar)
            ).day == 1
        )
    }

    @Test
    func monthWrapsWithoutChangingYear() throws {
        let december = try date(year: 2026, month: 12, day: 16, hour: 14, minute: 30)
        let january = AlertDateEditing.stepping(
            .month,
            by: 1,
            in: december,
            calendar: calendar
        )
        let result = components(january)

        #expect(result.year == 2026)
        #expect(result.month == 1)
        #expect(result.day == 16)
    }

    @Test
    func changingMonthOrYearClampsInvalidDay() throws {
        let january31 = try date(year: 2027, month: 1, day: 31, hour: 14, minute: 30)
        let leapDay = try date(year: 2028, month: 2, day: 29, hour: 14, minute: 30)

        #expect(
            components(
                AlertDateEditing.stepping(
                    .month,
                    by: 1,
                    in: january31,
                    calendar: calendar
                )
            ).day == 28
        )
        let nextYear = components(
            AlertDateEditing.stepping(.year, by: 1, in: leapDay, calendar: calendar)
        )
        #expect(nextYear.year == 2029)
        #expect(nextYear.month == 2)
        #expect(nextYear.day == 28)
    }

    @Test
    func hourAndMinuteWrapIndependently() throws {
        let late = try date(year: 2026, month: 9, day: 16, hour: 23, minute: 59)
        let early = try date(year: 2026, month: 9, day: 16, hour: 0, minute: 0)
        let wrappedHour = components(
            AlertDateEditing.stepping(.hour, by: 1, in: late, calendar: calendar)
        )
        let wrappedMinute = components(
            AlertDateEditing.stepping(.minute, by: 1, in: late, calendar: calendar)
        )
        let previousHour = components(
            AlertDateEditing.stepping(.hour, by: -1, in: early, calendar: calendar)
        )
        let previousMinute = components(
            AlertDateEditing.stepping(.minute, by: -1, in: early, calendar: calendar)
        )

        #expect(wrappedHour.hour == 0)
        #expect(wrappedHour.minute == 59)
        #expect(wrappedMinute.hour == 23)
        #expect(wrappedMinute.minute == 0)
        #expect(previousHour.hour == 23)
        #expect(previousHour.minute == 0)
        #expect(previousMinute.hour == 0)
        #expect(previousMinute.minute == 59)
    }

    @Test
    func caretLocationsSelectDateAndTimeComponents() {
        let dateComponents: [AlertDateComponent] = [.day, .month, .year]
        let timeComponents: [AlertDateComponent] = [.hour, .minute]

        #expect(
            AlertDateEditing.component(
                atCaretLocation: 0,
                in: "16/09/2026",
                components: dateComponents
            ) == .day
        )
        #expect(
            AlertDateEditing.component(
                atCaretLocation: 2,
                in: "16/09/2026",
                components: dateComponents
            ) == .day
        )
        #expect(
            AlertDateEditing.component(
                atCaretLocation: 3,
                in: "16/09/2026",
                components: dateComponents
            ) == .month
        )
        #expect(
            AlertDateEditing.component(
                atCaretLocation: 10,
                in: "16/09/2026",
                components: dateComponents
            ) == .year
        )
        #expect(
            AlertDateEditing.component(
                atCaretLocation: 5,
                in: "23:59",
                components: timeComponents
            ) == .minute
        )
    }

    private func date(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int
    ) throws -> Date {
        try #require(
            calendar.date(
                from: DateComponents(
                    year: year,
                    month: month,
                    day: day,
                    hour: hour,
                    minute: minute
                )
            )
        )
    }

    private func components(_ date: Date) -> DateComponents {
        calendar.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: date
        )
    }
}
