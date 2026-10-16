import Foundation

struct AlertValidationResult: Equatable, Sendable {
    var messageError: String?
    var scheduleError: String?
    var endDateError: String?

    var isValid: Bool {
        messageError == nil && scheduleError == nil && endDateError == nil
    }
}

struct AlertValidator: Sendable {
    let calculator: RecurrenceCalculator

    init(calculator: RecurrenceCalculator = RecurrenceCalculator()) {
        self.calculator = calculator
    }

    func validate(
        _ draft: AlertDraft,
        now: Date,
        calendar: Calendar = .current
    ) -> AlertValidationResult {
        let trimmedMessage = draft.message.trimmingCharacters(in: .whitespacesAndNewlines)
        let messageError: String? = switch trimmedMessage.count {
        case 0: "Enter a message."
        case 501...: "Messages can contain at most 500 characters."
        default: nil
        }

        let minimumEndDate = minimumEndDate(for: draft, now: now, calendar: calendar)
        let scheduleError: String?
        if draft.recurrence == .oneTime && draft.scheduledDate <= now {
            scheduleError = "Choose a time in the future."
        } else if draft.recurrence == .weekly && draft.weekdayMask == 0 {
            scheduleError = "Select at least one weekday."
        } else if draft.recurrence != .oneTime,
                  minimumEndDate == nil {
            scheduleError = "This recurrence does not have a future occurrence."
        } else {
            scheduleError = nil
        }

        let endDateError: String?
        if draft.recurrence != .oneTime,
           let endDate = draft.endDate,
           let minimumEndDate,
           calendar.startOfDay(for: endDate) < minimumEndDate {
            endDateError = "Choose an end date on or after the next alert."
        } else {
            endDateError = nil
        }

        return AlertValidationResult(
            messageError: messageError,
            scheduleError: scheduleError,
            endDateError: endDateError
        )
    }

    func minimumEndDate(
        for draft: AlertDraft,
        now: Date,
        calendar: Calendar = .current
    ) -> Date? {
        guard draft.recurrence != .oneTime else {
            return nil
        }
        var schedule = draft.snapshot(calendar: calendar)
        schedule.endDate = nil
        return calculator.nextOccurrence(after: now, schedule: schedule, calendar: calendar)
            .map { calendar.startOfDay(for: $0) }
    }
}
