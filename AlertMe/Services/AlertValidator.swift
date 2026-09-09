import Foundation

struct AlertValidationResult: Equatable, Sendable {
    var messageError: String?
    var scheduleError: String?

    var isValid: Bool {
        messageError == nil && scheduleError == nil
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

        let scheduleError: String?
        if draft.recurrence == .oneTime && draft.scheduledDate <= now {
            scheduleError = "Choose a time in the future."
        } else if draft.recurrence == .weekly && draft.weekdayMask == 0 {
            scheduleError = "Select at least one weekday."
        } else if draft.recurrence != .oneTime,
                  calculator.nextOccurrence(
                    after: now,
                    schedule: draft.snapshot(calendar: calendar),
                    calendar: calendar
                  ) == nil {
            scheduleError = "This recurrence does not have a future occurrence."
        } else {
            scheduleError = nil
        }

        return AlertValidationResult(messageError: messageError, scheduleError: scheduleError)
    }
}
