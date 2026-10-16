import Foundation
import Testing
@testable import AlertMe

struct RecurrenceCalculatorTests {
    private let calculator = RecurrenceCalculator()

    @Test
    func oneTimeOnlyReturnsFutureDate() {
        let now = Date(timeIntervalSince1970: 1_000)
        let future = Date(timeIntervalSince1970: 2_040)
        let schedule = makeSchedule(recurrence: .oneTime, oneTimeDate: future, startDate: future)

        #expect(calculator.nextOccurrence(after: now, schedule: schedule, calendar: utcCalendar()) == future)
        #expect(calculator.nextOccurrence(after: future, schedule: schedule, calendar: utcCalendar()) == nil)
    }

    @Test
    func oneTimeDropsHiddenSeconds() throws {
        let calendar = utcCalendar()
        let now = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 9, day: 9, hour: 10, minute: 28))
        )
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
        let schedule = makeSchedule(
            recurrence: .oneTime,
            oneTimeDate: selectedDate,
            startDate: selectedDate
        )

        let expected = calendar.date(
            from: DateComponents(year: 2026, month: 9, day: 9, hour: 10, minute: 29)
        )
        #expect(calculator.nextOccurrence(after: now, schedule: schedule, calendar: calendar) == expected)
    }

    @Test
    func recurringOccurrencesUseSecondZero() throws {
        let calendar = utcCalendar()
        let start = try #require(
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
        let schedule = makeSchedule(
            recurrence: .daily,
            startDate: start,
            hour: 10,
            minute: 29
        )

        let next = try #require(
            calculator.nextOccurrence(
                after: start.addingTimeInterval(-60),
                schedule: schedule,
                calendar: calendar
            )
        )
        #expect(calendar.component(.second, from: next) == 0)
    }

    @Test
    func weeklySelectsSoonestConfiguredWeekday() throws {
        let calendar = utcCalendar()
        let monday = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 7, hour: 10)))
        let schedule = makeSchedule(
            recurrence: .weekly,
            startDate: monday,
            hour: 15,
            minute: 45,
            weekdayMask: WeekdayMask.value(for: 3) | WeekdayMask.value(for: 5)
        )

        let next = calculator.nextOccurrence(after: monday, schedule: schedule, calendar: calendar)
        let expected = calendar.date(from: DateComponents(year: 2026, month: 9, day: 8, hour: 15, minute: 45))
        #expect(next == expected)
    }

    @Test
    func monthlySkipsMonthsWithoutConfiguredDay() throws {
        let calendar = utcCalendar()
        let start = try #require(calendar.date(from: DateComponents(year: 2026, month: 4, day: 1)))
        let schedule = makeSchedule(
            recurrence: .monthly,
            startDate: start,
            hour: 9,
            monthDay: 31
        )

        let next = calculator.nextOccurrence(after: start, schedule: schedule, calendar: calendar)
        let expected = calendar.date(from: DateComponents(year: 2026, month: 5, day: 31, hour: 9))
        #expect(next == expected)
    }

    @Test
    func yearlyFebruary29SkipsNonLeapYears() throws {
        let calendar = utcCalendar()
        let start = try #require(calendar.date(from: DateComponents(year: 2025, month: 3, day: 1)))
        let schedule = makeSchedule(
            recurrence: .yearly,
            startDate: start,
            hour: 8,
            monthDay: 29,
            month: 2
        )

        let next = calculator.nextOccurrence(after: start, schedule: schedule, calendar: calendar)
        let expected = calendar.date(from: DateComponents(year: 2028, month: 2, day: 29, hour: 8))
        #expect(next == expected)
    }

    @Test(arguments: [RecurrenceKind.daily, .weekly, .monthly, .yearly])
    func endDateIncludesFinalDayAndStopsFollowingOccurrence(recurrence: RecurrenceKind) throws {
        let calendar = utcCalendar()
        let start = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 6, day: 16, hour: 9))
        )
        var schedule = makeSchedule(
            recurrence: recurrence,
            startDate: start,
            hour: 9,
            weekdayMask: WeekdayMask.value(for: calendar.component(.weekday, from: start)),
            monthDay: 16,
            month: 6
        )
        schedule.endDate = calendar.startOfDay(for: start)

        #expect(calculator.nextOccurrence(
            after: start.addingTimeInterval(-1), schedule: schedule, calendar: calendar
        ) == start)
        #expect(calculator.nextOccurrence(
            after: start, schedule: schedule, calendar: calendar
        ) == nil)
    }

    @Test
    func endDateBetweenOccurrencesDoesNotAddExtraAlert() throws {
        let calendar = utcCalendar()
        let start = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 9, day: 10, hour: 9))
        )
        var schedule = makeSchedule(recurrence: .monthly, startDate: start, hour: 9, monthDay: 10)
        schedule.endDate = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 10, day: 9))
        )

        #expect(calculator.nextOccurrence(after: start, schedule: schedule, calendar: calendar) == nil)
    }

    @Test
    func cutoffUsesLocalCalendarDayAcrossDaylightSavingChange() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/Los_Angeles"))
        let start = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 11, day: 1))
        )
        var schedule = makeSchedule(recurrence: .daily, startDate: start, hour: 23, minute: 30)
        schedule.endDate = start
        let final = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 11, day: 1, hour: 23, minute: 30))
        )

        #expect(calculator.nextOccurrence(after: start, schedule: schedule, calendar: calendar) == final)
        #expect(calculator.nextOccurrence(after: final, schedule: schedule, calendar: calendar) == nil)
    }

    @Test
    func leapDayAfterCutoffIsNotScheduled() throws {
        let calendar = utcCalendar()
        let start = try #require(
            calendar.date(from: DateComponents(year: 2025, month: 3, day: 1))
        )
        var schedule = makeSchedule(
            recurrence: .yearly, startDate: start, hour: 8, monthDay: 29, month: 2
        )
        schedule.endDate = try #require(
            calendar.date(from: DateComponents(year: 2028, month: 2, day: 28))
        )

        #expect(calculator.nextOccurrence(after: start, schedule: schedule, calendar: calendar) == nil)
    }

    private func makeSchedule(
        recurrence: RecurrenceKind,
        oneTimeDate: Date? = nil,
        startDate: Date,
        hour: Int = 10,
        minute: Int = 0,
        weekdayMask: Int = 0,
        monthDay: Int = 1,
        month: Int = 1
    ) -> AlertScheduleSnapshot {
        AlertScheduleSnapshot(
            id: UUID(),
            recurrence: recurrence,
            oneTimeDate: oneTimeDate,
            startDate: startDate,
            hour: hour,
            minute: minute,
            weekdayMask: weekdayMask,
            monthDay: monthDay,
            month: month
        )
    }

    private func utcCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
}
