import Foundation

struct AlertDraft: Equatable, Sendable {
    var message = ""
    var scheduledDate: Date
    var recurrence: RecurrenceKind = .oneTime
    var weekdayMask: Int
    var isEnabled = true
    var isSilent = false

    init(now: Date = Date(), calendar: Calendar = .current) {
        let proposedDate = calendar.date(byAdding: .minute, value: 5, to: now) ?? now.addingTimeInterval(300)
        scheduledDate = proposedDate
        let weekday = calendar.component(.weekday, from: proposedDate)
        weekdayMask = WeekdayMask.value(for: weekday)
    }

    init(definition: AlertDefinition) {
        message = definition.message
        scheduledDate = definition.oneTimeDate ?? definition.startDate
        recurrence = definition.recurrence
        weekdayMask = definition.weekdayMask
        isEnabled = definition.isEnabled
        isSilent = definition.isSilent
    }

    func snapshot(id: UUID = UUID(), calendar: Calendar = .current) -> AlertScheduleSnapshot {
        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: scheduledDate
        )
        let minuteDate = calendar.date(from: components) ?? scheduledDate
        return AlertScheduleSnapshot(
            id: id,
            recurrence: recurrence,
            oneTimeDate: recurrence == .oneTime ? minuteDate : nil,
            startDate: minuteDate,
            hour: components.hour ?? 0,
            minute: components.minute ?? 0,
            weekdayMask: weekdayMask,
            monthDay: components.day ?? 1,
            month: components.month ?? 1
        )
    }
}

enum WeekdayMask {
    static func value(for calendarWeekday: Int) -> Int {
        1 << (calendarWeekday - 1)
    }

    static func contains(_ mask: Int, calendarWeekday: Int) -> Bool {
        mask & value(for: calendarWeekday) != 0
    }
}
