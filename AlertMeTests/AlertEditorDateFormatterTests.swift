import Foundation
import Testing
@testable import AlertMe

@MainActor
struct AlertEditorDateFormatterTests {
    @Test
    func formatsEditorDateDayFirst() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 9, day: 30))
        )
        AlertDateTimeControls.dateFormatter.timeZone = calendar.timeZone

        #expect(AlertDateTimeControls.dateFormatter.string(from: date) == "30/09/2026")
    }
}
