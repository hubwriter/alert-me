import Foundation

enum AlertDateComponent: Sendable {
    case day
    case month
    case year
    case hour
    case minute
}

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

    static func stepping(
        _ component: AlertDateComponent,
        by amount: Int,
        in value: Date,
        calendar: Calendar = .current
    ) -> Date {
        var components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: value
        )

        switch component {
        case .day:
            guard let day = components.day,
                  let range = calendar.range(of: .day, in: .month, for: value) else {
                return value
            }
            components.day = wrapped(day + amount, in: range)
        case .month:
            guard let month = components.month else {
                return value
            }
            components.month = wrapped(month + amount, in: 1..<13)
            components.day = validDay(for: components, calendar: calendar)
        case .year:
            guard let year = components.year else {
                return value
            }
            components.year = year + amount
            components.day = validDay(for: components, calendar: calendar)
        case .hour:
            guard let hour = components.hour else {
                return value
            }
            components.hour = wrapped(hour + amount, in: 0..<24)
        case .minute:
            guard let minute = components.minute else {
                return value
            }
            components.minute = wrapped(minute + amount, in: 0..<60)
        }

        return calendar.date(from: components) ?? value
    }

    static func component(
        atCaretLocation location: Int,
        in formattedValue: String,
        components: [AlertDateComponent]
    ) -> AlertDateComponent? {
        let fullRange = NSRange(formattedValue.startIndex..., in: formattedValue)
        let matches = try? NSRegularExpression(pattern: #"\d+"#)
            .matches(in: formattedValue, range: fullRange)

        return zip(matches ?? [], components).first {
            location >= $0.0.range.location
                && location <= NSMaxRange($0.0.range)
        }?.1
    }

    private static func wrapped(_ value: Int, in range: Range<Int>) -> Int {
        let count = range.count
        return range.lowerBound + (value - range.lowerBound).modulo(count)
    }

    private static func validDay(
        for components: DateComponents,
        calendar: Calendar
    ) -> Int? {
        guard let requestedDay = components.day else {
            return nil
        }
        var firstOfMonth = components
        firstOfMonth.day = 1
        guard let date = calendar.date(from: firstOfMonth),
              let range = calendar.range(of: .day, in: .month, for: date) else {
            return requestedDay
        }
        return min(requestedDay, range.count)
    }
}

private extension Int {
    func modulo(_ divisor: Int) -> Int {
        let remainder = self % divisor
        return remainder >= 0 ? remainder : remainder + divisor
    }
}
