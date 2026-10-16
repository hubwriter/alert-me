import Foundation
import Testing
@testable import AlertMe

struct AlertValidatorTests {
    @Test
    func rejectsEmptyAndOversizedMessages() {
        let now = Date()
        var empty = AlertDraft(now: now)
        empty.message = "   "
        #expect(AlertValidator().validate(empty, now: now).messageError != nil)

        var oversized = AlertDraft(now: now)
        oversized.message = String(repeating: "a", count: 501)
        #expect(AlertValidator().validate(oversized, now: now).messageError != nil)
    }

    @Test
    func rejectsPastOneTimeAlert() {
        let now = Date()
        var draft = AlertDraft(now: now)
        draft.message = "Dentist appointment"
        draft.scheduledDate = now.addingTimeInterval(-1)

        #expect(AlertValidator().validate(draft, now: now).scheduleError != nil)
    }

    @Test
    func rejectsWeeklyAlertWithoutWeekdays() {
        let now = Date()
        var draft = AlertDraft(now: now)
        draft.message = "Team meeting"
        draft.recurrence = .weekly
        draft.weekdayMask = 0

        #expect(AlertValidator().validate(draft, now: now).scheduleError != nil)
    }

    @Test(arguments: [RecurrenceKind.daily, .weekly, .monthly, .yearly])
    func endDateCannotPrecedeNextTrigger(recurrence: RecurrenceKind) throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let now = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 6, day: 17, hour: 12))
        )
        var draft = AlertDraft(now: now, calendar: calendar)
        draft.message = "Recurring alert"
        draft.recurrence = recurrence
        draft.scheduledDate = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 6, day: 16, hour: 9))
        )
        draft.weekdayMask = WeekdayMask.value(for: 3)
        let expectedComponents: DateComponents = switch recurrence {
        case .daily: DateComponents(year: 2026, month: 6, day: 18)
        case .weekly: DateComponents(year: 2026, month: 6, day: 23)
        case .monthly: DateComponents(year: 2026, month: 7, day: 16)
        case .yearly: DateComponents(year: 2027, month: 6, day: 16)
        case .oneTime: DateComponents()
        }
        let expected = try #require(calendar.date(from: expectedComponents))
        let validator = AlertValidator()

        draft.endDate = try #require(calendar.date(byAdding: .day, value: -1, to: expected))
        #expect(validator.minimumEndDate(for: draft, now: now, calendar: calendar) == expected)
        #expect(validator.validate(draft, now: now, calendar: calendar).endDateError != nil)
        #expect(!validator.validate(draft, now: now, calendar: calendar).isValid)

        draft.endDate = expected
        #expect(validator.validate(draft, now: now, calendar: calendar).isValid)
        draft.endDate = nil
        #expect(validator.validate(draft, now: now, calendar: calendar).isValid)
    }

    @Test
    func oneTimeAlertIgnoresDraftEndDate() {
        let now = Date()
        var draft = AlertDraft(now: now)
        draft.message = "One time"
        draft.endDate = now.addingTimeInterval(-86_400)

        #expect(draft.snapshot().endDate == nil)
        #expect(AlertValidator().validate(draft, now: now).isValid)
    }
}
