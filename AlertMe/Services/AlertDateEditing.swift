import Foundation

enum AlertDateEditing {
    static func startOfMinute(_ date: Date, calendar: Calendar = .current) -> Date {
        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: date
        )
        return calendar.date(from: components) ?? date
    }

    static func replacingDate(
        in value: Date,
        with date: Date,
        calendar: Calendar = .current
    ) -> Date {
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: value)
        var combined = DateComponents()
        combined.year = dateComponents.year
        combined.month = dateComponents.month
        combined.day = dateComponents.day
        combined.hour = timeComponents.hour
        combined.minute = timeComponents.minute
        return calendar.date(from: combined) ?? value
    }

    static func replacingTime(
        in value: Date,
        with time: Date,
        calendar: Calendar = .current
    ) -> Date {
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: value)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
        var combined = DateComponents()
        combined.year = dateComponents.year
        combined.month = dateComponents.month
        combined.day = dateComponents.day
        combined.hour = timeComponents.hour
        combined.minute = timeComponents.minute
        return calendar.date(from: combined) ?? value
    }

    static func addingDays(
        _ days: Int,
        to value: Date,
        calendar: Calendar = .current
    ) -> Date {
        calendar.date(byAdding: .day, value: days, to: value) ?? value
    }

    static func addingMinutes(
        _ minutes: Int,
        to value: Date,
        calendar: Calendar = .current
    ) -> Date {
        calendar.date(byAdding: .minute, value: minutes, to: value) ?? value
    }
}
