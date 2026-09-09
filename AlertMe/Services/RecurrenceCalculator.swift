import Foundation

struct AlertScheduleSnapshot: Equatable, Sendable {
    let id: UUID
    let recurrence: RecurrenceKind
    let oneTimeDate: Date?
    let startDate: Date
    let hour: Int
    let minute: Int
    let weekdayMask: Int
    let monthDay: Int
    let month: Int
}

struct RecurrenceCalculator: Sendable {
    func nextOccurrence(
        after date: Date,
        schedule: AlertScheduleSnapshot,
        calendar: Calendar
    ) -> Date? {
        let normalizedStartDate = startOfMinute(schedule.startDate, calendar: calendar)

        switch schedule.recurrence {
        case .oneTime:
            guard let oneTimeDate = schedule.oneTimeDate.map({
                startOfMinute($0, calendar: calendar)
            }), oneTimeDate > date else {
                return nil
            }
            return oneTimeDate
        case .daily:
            return nextDaily(
                after: date,
                schedule: schedule,
                startDate: normalizedStartDate,
                calendar: calendar
            )
        case .weekly:
            return nextWeekly(
                after: date,
                schedule: schedule,
                startDate: normalizedStartDate,
                calendar: calendar
            )
        case .monthly:
            return nextMonthly(
                after: date,
                schedule: schedule,
                startDate: normalizedStartDate,
                calendar: calendar
            )
        case .yearly:
            return nextYearly(
                after: date,
                schedule: schedule,
                startDate: normalizedStartDate,
                calendar: calendar
            )
        }
    }

    private func nextDaily(
        after date: Date,
        schedule: AlertScheduleSnapshot,
        startDate: Date,
        calendar: Calendar
    ) -> Date? {
        nextMatching(
            after: max(date, startDate.addingTimeInterval(-1)),
            components: DateComponents(
                hour: schedule.hour,
                minute: schedule.minute,
                second: 0
            ),
            calendar: calendar
        )
    }

    private func nextWeekly(
        after date: Date,
        schedule: AlertScheduleSnapshot,
        startDate: Date,
        calendar: Calendar
    ) -> Date? {
        let searchStart = max(date, startDate.addingTimeInterval(-1))
        return (1...7)
            .filter { WeekdayMask.contains(schedule.weekdayMask, calendarWeekday: $0) }
            .compactMap { weekday in
                nextMatching(
                    after: searchStart,
                    components: DateComponents(
                        hour: schedule.hour,
                        minute: schedule.minute,
                        second: 0,
                        weekday: weekday
                    ),
                    calendar: calendar
                )
            }
            .min()
    }

    private func nextMonthly(
        after date: Date,
        schedule: AlertScheduleSnapshot,
        startDate: Date,
        calendar: Calendar
    ) -> Date? {
        let searchStart = max(date, startDate.addingTimeInterval(-1))
        var monthCursor = calendar.date(
            from: calendar.dateComponents([.year, .month], from: searchStart)
        ) ?? searchStart

        for _ in 0..<4_800 {
            let monthComponents = calendar.dateComponents([.year, .month], from: monthCursor)
            if let candidate = candidate(
                year: monthComponents.year,
                month: monthComponents.month,
                day: schedule.monthDay,
                schedule: schedule,
                startDate: startDate,
                after: searchStart,
                calendar: calendar
            ) {
                return candidate
            }
            guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthCursor) else {
                return nil
            }
            monthCursor = nextMonth
        }
        return nil
    }

    private func nextYearly(
        after date: Date,
        schedule: AlertScheduleSnapshot,
        startDate: Date,
        calendar: Calendar
    ) -> Date? {
        let searchStart = max(date, startDate.addingTimeInterval(-1))
        let startYear = calendar.component(.year, from: searchStart)

        for year in startYear..<(startYear + 400) {
            if let candidate = candidate(
                year: year,
                month: schedule.month,
                day: schedule.monthDay,
                schedule: schedule,
                startDate: startDate,
                after: searchStart,
                calendar: calendar
            ) {
                return candidate
            }
        }
        return nil
    }

    private func candidate(
        year: Int?,
        month: Int?,
        day: Int,
        schedule: AlertScheduleSnapshot,
        startDate: Date,
        after date: Date,
        calendar: Calendar
    ) -> Date? {
        guard let year, let month else {
            return nil
        }
        var dayComponents = DateComponents()
        dayComponents.calendar = calendar
        dayComponents.timeZone = calendar.timeZone
        dayComponents.year = year
        dayComponents.month = month
        dayComponents.day = day

        guard let dayStart = calendar.date(from: dayComponents) else {
            return nil
        }
        let resolvedDay = calendar.dateComponents([.year, .month, .day], from: dayStart)
        guard resolvedDay.year == year, resolvedDay.month == month, resolvedDay.day == day else {
            return nil
        }

        let candidate = nextMatching(
            after: dayStart.addingTimeInterval(-1),
            components: DateComponents(
                hour: schedule.hour,
                minute: schedule.minute,
                second: 0
            ),
            calendar: calendar
        )
        guard let candidate else {
            return nil
        }
        let candidateDay = calendar.dateComponents([.year, .month, .day], from: candidate)
        guard candidateDay.year == year,
              candidateDay.month == month,
              candidateDay.day == day,
              candidate > date,
              candidate >= startDate else {
            return nil
        }
        return candidate
    }

    private func nextMatching(
        after date: Date,
        components: DateComponents,
        calendar: Calendar
    ) -> Date? {
        calendar.nextDate(
            after: date,
            matching: components,
            matchingPolicy: .nextTimePreservingSmallerComponents,
            repeatedTimePolicy: .first,
            direction: .forward
        )
    }

    private func startOfMinute(_ date: Date, calendar: Calendar) -> Date {
        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: date
        )
        return calendar.date(from: components) ?? date
    }
}
