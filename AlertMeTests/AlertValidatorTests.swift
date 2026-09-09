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
}
