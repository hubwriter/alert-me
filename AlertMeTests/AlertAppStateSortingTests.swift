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
            ("Next Sunday", 25, 23, 59),
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

        #expect(sections.map(\.title) == ["Today", "Later this week", "Next week", "Future", "Past"])
        #expect(sections.map { $0.definitions.map(\.message) } == [
            ["Soon", "Tonight"],
            ["Tomorrow", "Sunday"],
            ["Next week", "Next Sunday"],
            ["Distant"],
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

        #expect(sections.map(\.title) == [day == 25 ? "Today" : "Later this week", "Next week"])
        #expect(sections.map { $0.definitions.map(\.message) } == [
            ["Sunday night"], ["Monday midnight"]
        ])
    }

    @Test(arguments: [(2026, 3, 23), (2026, 10, 19), (2026, 12, 28)], [1, 2])
    func nextWeekIncludesExactlyMondayThroughSundayAcrossCalendarTransitions(
        mondayComponents: (Int, Int, Int),
        firstWeekday: Int
    ) throws {
        var calendar = calendar(timeZone: "Europe/London")
        calendar.firstWeekday = firstWeekday
        let (year, month, day) = mondayComponents
        let monday = try #require(calendar.date(from: DateComponents(year: year, month: month, day: day)))
        let followingMonday = try #require(calendar.date(byAdding: .day, value: 7, to: monday))
        let now = try #require(calendar.date(byAdding: .day, value: -3, to: monday))
        let definitions = [
            ("Following Monday", followingMonday),
            ("Sunday night", followingMonday.addingTimeInterval(-1)),
            ("Monday midnight", monday),
            ("Before next week", monday.addingTimeInterval(-1))
        ].map { message, date in
            makeDefinition(message: message, recurrence: .oneTime, date: date)
        }

        let sections = AlertAppState.listSections(
            from: definitions,
            relativeTo: now,
            calendar: calendar
        )

        #expect(sections.map(\.title) == ["Later this week", "Next week", "Future"])
        #expect(sections.map { $0.definitions.map(\.message) } == [
            ["Before next week"], ["Monday midnight", "Sunday night"], ["Following Monday"]
        ])
    }

    @Test(arguments: ["America/Los_Angeles", "Europe/London", "Asia/Tokyo"])
    func nextWeekSectionsRefreshAtLocalMondayMidnight(timeZone: String) throws {
        let calendar = calendar(timeZone: timeZone)
        let monday = try date(day: 19, calendar: calendar)
        let definitions = try [
            ("Monday morning", 19, 9),
            ("Sunday", 25, 12),
            ("Following Monday", 26, 12)
        ].map { message, day, hour in
            makeDefinition(
                message: message,
                recurrence: .oneTime,
                date: try date(day: day, hour: hour, calendar: calendar)
            )
        }

        let before = AlertAppState.listSections(
            from: definitions,
            relativeTo: monday.addingTimeInterval(-1),
            calendar: calendar
        )
        let after = AlertAppState.listSections(
            from: definitions,
            relativeTo: monday,
            calendar: calendar
        )

        #expect(before.map(\.title) == ["Next week", "Future"])
        #expect(before.map { $0.definitions.map(\.message) } == [
            ["Monday morning", "Sunday"], ["Following Monday"]
        ])
        #expect(after.map(\.title) == ["Today", "Later this week", "Next week"])
        #expect(after.map { $0.definitions.map(\.message) } == [
            ["Monday morning"], ["Sunday"], ["Following Monday"]
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

        #expect(sections.map(\.title) == ["Later this week", "Next week"])
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
        let monthly = makeDefinition(message: "Monthly", recurrence: .monthly, date: start)
        monthly.monthDay = 21
        monthly.isEnabled = false
        monthly.nextOccurrenceAt = start
        let unscheduled = makeDefinition(message: "Unscheduled", recurrence: .monthly, date: start)
        let disabled = makeDefinition(
            message: "Disabled",
            recurrence: .oneTime,
            date: try date(day: 16, hour: 18, calendar: calendar)
        )
        disabled.isEnabled = false

        let sections = AlertAppState.listSections(
            from: [unscheduled, yearly, weekly, disabled, daily, monthly],
            relativeTo: now,
            calendar: calendar
        )

        #expect(sections.map(\.title) == ["Today", "Later this week", "Next week", "Future"])
        #expect(sections.map { $0.definitions.map(\.message) } == [
            ["Daily", "Disabled"], ["Weekly"], ["Monthly"], ["Yearly", "Unscheduled"]
        ])
    }

    @Test
    func disabledDailyAlertsRefreshTheirOccurrenceForSectionsAndOrdering() throws {
        let calendar = calendar()
        let now = try date(day: 17, hour: 9, calendar: calendar)
        let afternoon = makeDefinition(
            message: "Afternoon",
            recurrence: .daily,
            date: try date(day: 16, hour: 15, calendar: calendar)
        )
        afternoon.hour = 15
        afternoon.isEnabled = false
        afternoon.nextOccurrenceAt = try date(day: 16, hour: 15, calendar: calendar)

        let morning = makeDefinition(
            message: "Morning",
            recurrence: .daily,
            date: try date(day: 16, hour: 10, calendar: calendar)
        )
        morning.hour = 10
        morning.isEnabled = false
        morning.nextOccurrenceAt = try date(day: 18, hour: 10, calendar: calendar)

        let sections = AlertAppState.listSections(
            from: [afternoon, morning],
            relativeTo: now,
            calendar: calendar
        )

        #expect(sections.map(\.title) == ["Today"])
        #expect(sections.first?.definitions.map(\.message) == ["Morning", "Afternoon"])
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

    @Test
    func completedRecurrenceMovesToPastBeforeCutoffDayPasses() throws {
        let calendar = Calendar.current
        let occurrence = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 6, day: 10, hour: 9))
        )
        let definition = makeDefinition(message: "Monthly", recurrence: .monthly, date: occurrence)
        definition.hour = 9
        definition.monthDay = 10
        definition.endDate = calendar.date(from: DateComponents(year: 2026, month: 6, day: 30))
        definition.nextOccurrenceAt = occurrence

        let before = occurrence.addingTimeInterval(-1)
        #expect(AlertAppState.futureDefinitions(from: [definition], relativeTo: before).count == 1)
        #expect(AlertAppState.pastDefinitions(from: [definition], relativeTo: before).isEmpty)
        #expect(AlertAppState.listSections(from: [definition], relativeTo: before).map(\.title) == ["Today"])

        definition.lastHandledOccurrence = occurrence
        definition.nextOccurrenceAt = nil
        let after = occurrence.addingTimeInterval(1)
        #expect(AlertAppState.futureDefinitions(from: [definition], relativeTo: after).isEmpty)
        #expect(AlertAppState.pastDefinitions(from: [definition], relativeTo: after).count == 1)
        #expect(AlertAppState.listSections(from: [definition], relativeTo: after).map(\.title) == ["Past"])
    }

    @Test
    func completedRecurrencesSortByFinalTriggerAndUnlimitedAlertsStayFuture() throws {
        let calendar = Calendar.current
        let recentDate = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 6, day: 10, hour: 9))
        )
        let olderDate = recentDate.addingTimeInterval(-86_400)
        let recent = makeDefinition(message: "Recent", recurrence: .daily, date: recentDate)
        let older = makeDefinition(message: "Older", recurrence: .daily, date: olderDate)
        let unlimited = makeDefinition(message: "Unlimited", recurrence: .daily, date: olderDate)
        let disabled = makeDefinition(message: "Disabled", recurrence: .daily, date: olderDate)
        for definition in [recent, older, disabled] {
            definition.hour = 9
            definition.endDate = calendar.startOfDay(for: definition.startDate)
        }
        recent.lastHandledOccurrence = recentDate
        older.lastHandledOccurrence = olderDate
        disabled.isEnabled = false
        let now = recentDate.addingTimeInterval(1)

        #expect(AlertAppState.pastDefinitions(
            from: [older, recent], relativeTo: now
        ).map(\.message) == ["Recent", "Older"])
        #expect(AlertAppState.futureDefinitions(from: [unlimited], relativeTo: now).count == 1)
        #expect(AlertAppState.pastDefinitions(from: [disabled], relativeTo: now).count == 1)
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
