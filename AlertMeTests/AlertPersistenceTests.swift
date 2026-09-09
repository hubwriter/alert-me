import Foundation
import SwiftData
import Testing
@testable import AlertMe

@MainActor
struct AlertPersistenceTests {
    @Test
    func storesAndFetchesAlertDefinition() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: AlertDefinition.self,
            configurations: configuration
        )
        let context = ModelContext(container)
        let scheduledDate = Date().addingTimeInterval(3_600)
        let definition = AlertDefinition(
            message: "Dentist appointment",
            recurrence: .oneTime,
            oneTimeDate: scheduledDate,
            startDate: scheduledDate,
            hour: 11,
            minute: 0,
            weekdayMask: 0,
            monthDay: 1,
            month: 1
        )

        context.insert(definition)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<AlertDefinition>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.message == "Dentist appointment")
        #expect(fetched.first?.oneTimeDate == scheduledDate)
    }
}
