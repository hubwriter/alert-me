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
            month: month
        )
    }
}
