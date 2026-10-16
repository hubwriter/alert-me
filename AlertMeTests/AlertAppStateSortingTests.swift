import Foundation
import Testing
@testable import AlertMe

@MainActor
struct AlertAppStateSortingTests {
    @Test
    func futureAlertsAreOrderedByClosestNextOccurrence() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let yearly = makeDefinition(
            message: "Yearly",
            recurrence: .yearly,
            date: now.addingTimeInterval(-86_400)
        )
        yearly.nextOccurrenceAt = now.addingTimeInterval(31_449_600)
        let later = makeDefinition(
            message: "Later",
            recurrence: .oneTime,
            date: now.addingTimeInterval(7_200)
        )
        let sooner = makeDefinition(
            message: "Sooner",
            recurrence: .oneTime,
            date: now.addingTimeInterval(3_600)
        )

        let ordered = AlertAppState.futureDefinitions(
            from: [yearly, later, sooner],
            relativeTo: now
        )

        #expect(ordered.map(\.message) == ["Sooner", "Later", "Yearly"])
    }

    @Test
    func pastAlertsAreOrderedByClosestPreviousOccurrence() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let older = makeDefinition(
            message: "Older",
            recurrence: .oneTime,
            date: now.addingTimeInterval(-7_200)
        )
        let recent = makeDefinition(
            message: "Recent",
            recurrence: .oneTime,
            date: now.addingTimeInterval(-3_600)
        )

        let ordered = AlertAppState.pastDefinitions(
            from: [older, recent],
            relativeTo: now
        )

        #expect(ordered.map(\.message) == ["Recent", "Older"])
    }

    @Test
    func listSectionsPreserveOrderingAndKeepElapsedAlertsInPast() throws {
        let calendar = calendar()
        let now = try date(day: 16, hour: 12, calendar: calendar)
        let definitions = try [
            ("Next week", 19, 0, 0),
            ("Older", 15, 12, 0),
            ("Tonight", 16, 23, 59),
            ("Sunday", 18, 23, 59),
            ("Now", 16, 12, 0),
            ("Tomorrow", 17, 0, 0),
            ("Soon", 16, 12, 1),
            ("Earlier today", 16, 11, 0),
            ("Distant", 26, 12, 0)
        ].map { message, day, hour, minute in
            makeDefinition(
                message: message,
                recurrence: .oneTime,
                date: try date(day: day, hour: hour, minute: minute, calendar: calendar)
            )
        }

        let sections = AlertAppState.listSections(
            from: definitions,
            relativeTo: now,
            calendar: calendar
        )

        #expect(sections.map(\.title) == ["Today", "Later this week", "Future", "Past"])
        #expect(sections.map { $0.definitions.map(\.message) } == [
            ["Soon", "Tonight"],
            ["Tomorrow", "Sunday"],
            ["Next week", "Distant"],
            ["Now", "Earlier today", "Older"]
        ])
    }

    @Test(arguments: 19...25, [1, 2])
    func weekAlwaysEndsAfterSundayRegardlessOfFirstWeekday(day: Int, firstWeekday: Int) throws {
        var calendar = calendar(timeZone: "Europe/London")
        calendar.firstWeekday = firstWeekday
        let now = try date(day: day, hour: 12, calendar: calendar)
        let sunday = makeDefinition(
            message: "Sunday night",
            recurrence: .oneTime,
            date: try date(day: 25, hour: 23, minute: 59, calendar: calendar)
        )
        let monday = makeDefinition(
            message: "Monday midnight",
            recurrence: .oneTime,
            date: try date(day: 26, calendar: calendar)
        )

        let sections = AlertAppState.listSections(
            from: [monday, sunday],
            relativeTo: now,
            calendar: calendar
        )

        #expect(sections.map(\.title) == [day == 25 ? "Today" : "Later this week", "Future"])
        #expect(sections.map { $0.definitions.map(\.message) } == [
            ["Sunday night"], ["Monday midnight"]
        ])
    }

    @Test(arguments: ["America/Los_Angeles", "Europe/London", "Asia/Tokyo"])
    func sectionsRefreshAcrossLocalMidnight(timeZone: String) throws {
        let calendar = calendar(timeZone: timeZone)
        let midnight = try date(day: 17, calendar: calendar)
        let alert = makeDefinition(message: "Midnight", recurrence: .oneTime, date: midnight)
        let later = makeDefinition(
            message: "Morning",
            recurrence: .oneTime,
            date: try date(day: 17, hour: 9, calendar: calendar)
        )

        let before = AlertAppState.listSections(
            from: [later, alert],
            relativeTo: midnight.addingTimeInterval(-1),
            calendar: calendar
        )
        let after = AlertAppState.listSections(
            from: [later, alert],
            relativeTo: midnight,
            calendar: calendar
        )

        #expect(before.map(\.title) == ["Later this week"])
        #expect(before.first?.definitions.map(\.message) == ["Midnight", "Morning"])
        #expect(after.map(\.title) == ["Today", "Past"])
        #expect(after.map { $0.definitions.map(\.message) } == [["Morning"], ["Midnight"]])
    }

    @Test
    func weekGroupingCrossesYearBoundary() throws {
        let calendar = calendar()
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 12, day: 31, hour: 12)))
        let sundayDate = try #require(calendar.date(from: DateComponents(year: 2027, month: 1, day: 3, hour: 23)))
        let mondayDate = try #require(calendar.date(from: DateComponents(year: 2027, month: 1, day: 4)))
        let sunday = makeDefinition(message: "Sunday", recurrence: .oneTime, date: sundayDate)
        let monday = makeDefinition(message: "Monday", recurrence: .oneTime, date: mondayDate)

        let sections = AlertAppState.listSections(
            from: [monday, sunday],
            relativeTo: now,
            calendar: calendar
        )

        #expect(sections.map(\.title) == ["Later this week", "Future"])
        #expect(sections.map { $0.definitions.map(\.message) } == [["Sunday"], ["Monday"]])
    }

    @Test
    func recurringAndDisabledAlertsUseNextOccurrenceRatherThanStartDate() throws {
        let calendar = calendar()
        let now = try date(day: 16, hour: 12, calendar: calendar)
        let start = try date(day: 1, calendar: calendar)
        let daily = makeDefinition(message: "Daily", recurrence: .daily, date: start)
        daily.nextOccurrenceAt = try date(day: 16, hour: 15, calendar: calendar)
        let weekly = makeDefinition(message: "Weekly", recurrence: .weekly, date: start)
        weekly.nextOccurrenceAt = try date(day: 18, hour: 15, calendar: calendar)
        weekly.isEnabled = false
        let yearly = makeDefinition(message: "Yearly", recurrence: .yearly, date: start)
        yearly.nextOccurrenceAt = try date(day: 26, calendar: calendar)
        let unscheduled = makeDefinition(message: "Unscheduled", recurrence: .monthly, date: start)
        let disabled = makeDefinition(
            message: "Disabled",
            recurrence: .oneTime,
            date: try date(day: 16, hour: 18, calendar: calendar)
        )
        disabled.isEnabled = false

        let sections = AlertAppState.listSections(
            from: [unscheduled, yearly, weekly, disabled, daily],
            relativeTo: now,
            calendar: calendar
        )

        #expect(sections.map(\.title) == ["Today", "Later this week", "Future"])
        #expect(sections.map { $0.definitions.map(\.message) } == [
            ["Daily", "Disabled"], ["Weekly"], ["Yearly", "Unscheduled"]
        ])
    }

    @Test
    func emptyListsHaveNoSectionsAndPastOnlyListsHaveOnlyPast() throws {
        let calendar = calendar()
        let now = try date(day: 16, hour: 12, calendar: calendar)
        let past = makeDefinition(message: "Past", recurrence: .oneTime, date: now)

        #expect(AlertAppState.listSections(from: [], relativeTo: now, calendar: calendar).isEmpty)
        let sections = AlertAppState.listSections(from: [past], relativeTo: now, calendar: calendar)
        #expect(sections.map(\.title) == ["Past"])
        #expect(sections.first?.definitions.map(\.id) == [past.id])
    }

    private func calendar(timeZone: String = "UTC") -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZone)!
        return calendar
    }

    private func date(
        day: Int,
        hour: Int = 0,
        minute: Int = 0,
        calendar: Calendar
    ) throws -> Date {
        try #require(calendar.date(from: DateComponents(
            year: 2026, month: 10, day: day, hour: hour, minute: minute
        )))
    }

    private func makeDefinition(
        message: String,
        recurrence: RecurrenceKind,
        date: Date
    ) -> AlertDefinition {
        AlertDefinition(
            message: message,
            recurrence: recurrence,
            oneTimeDate: recurrence == .oneTime ? date : nil,
            startDate: date,
            hour: 0,
            minute: 0,
            weekdayMask: 0,
            monthDay: 1,
            month: 1
        )
    }
}
