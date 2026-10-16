import Foundation
import SwiftData

enum RecurrenceKind: String, CaseIterable, Codable, Identifiable, Sendable {
    case oneTime
    case daily
    case weekly
    case monthly
    case yearly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .oneTime: "One time"
        case .daily: "Daily"
        case .weekly: "Weekly"
        case .monthly: "Monthly"
        case .yearly: "Yearly"
        }
    }
}

enum AlertOutcome: String, Codable, Sendable {
    case scheduled
    case dismissed
    case missed
}

struct CalendarDate: Comparable, Equatable, Sendable {
    let year: Int
    let month: Int
    let day: Int

    init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    init(date: Date, calendar: Calendar = .current) {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        year = components.year ?? 1
        month = components.month ?? 1
        day = components.day ?? 1
    }

    func date(in calendar: Calendar) -> Date? {
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = year
        components.month = month
        components.day = day
        return calendar.date(from: components)
    }

    static func < (lhs: CalendarDate, rhs: CalendarDate) -> Bool {
        if lhs.year != rhs.year {
            return lhs.year < rhs.year
        }
        if lhs.month != rhs.month {
            return lhs.month < rhs.month
        }
        return lhs.day < rhs.day
    }
}

@Model
final class AlertDefinition {
    @Attribute(.unique) var id: UUID
    var message: String
    var recurrenceRawValue: String
    var oneTimeDate: Date?
    var startDate: Date
    var hour: Int
    var minute: Int
    var weekdayMask: Int
    var monthDay: Int
    var month: Int
    var isEnabled: Bool
    var isSilent: Bool
    var createdAt: Date
    var updatedAt: Date
    var lastHandledOccurrence: Date?
    var lastOutcomeRawValue: String?
    var missedCount: Int
    var nextOccurrenceAt: Date?
    var lastDismissedAt: Date?
    var endDate: Date?
    var endDateYear: Int?
    var endDateMonth: Int?
    var endDateDay: Int?

    init(
        id: UUID = UUID(),
        message: String,
        recurrence: RecurrenceKind,
        oneTimeDate: Date?,
        startDate: Date,
        hour: Int,
        minute: Int,
        weekdayMask: Int,
        monthDay: Int,
        month: Int,
        endDate: Date? = nil,
        endDateCalendarDay: CalendarDate? = nil,
        isEnabled: Bool = true,
        isSilent: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.message = message
        recurrenceRawValue = recurrence.rawValue
        self.oneTimeDate = oneTimeDate
        self.startDate = startDate
        self.hour = hour
        self.minute = minute
        self.weekdayMask = weekdayMask
        self.monthDay = monthDay
        self.month = month
        self.endDate = endDate
        endDateYear = endDateCalendarDay?.year
        endDateMonth = endDateCalendarDay?.month
        endDateDay = endDateCalendarDay?.day
        self.isEnabled = isEnabled
        self.isSilent = isSilent
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        missedCount = 0
    }

    var recurrence: RecurrenceKind {
        get { RecurrenceKind(rawValue: recurrenceRawValue) ?? .oneTime }
        set { recurrenceRawValue = newValue.rawValue }
    }

    var lastOutcome: AlertOutcome? {
        get { lastOutcomeRawValue.flatMap(AlertOutcome.init(rawValue:)) }
        set { lastOutcomeRawValue = newValue?.rawValue }
    }

    var endDateCalendarDay: CalendarDate? {
        if let endDateYear, let endDateMonth, let endDateDay {
            return CalendarDate(year: endDateYear, month: endDateMonth, day: endDateDay)
        }
        return endDate.map { CalendarDate(date: $0) }
    }

    var scheduleSnapshot: AlertScheduleSnapshot {
        AlertScheduleSnapshot(
            id: id,
            recurrence: recurrence,
            oneTimeDate: oneTimeDate,
            startDate: startDate,
            hour: hour,
            minute: minute,
            weekdayMask: weekdayMask,
            monthDay: monthDay,
            month: month,
            endDate: endDate,
            endDateCalendarDay: endDateCalendarDay
        )
    }
}
