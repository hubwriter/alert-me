import Foundation
import Testing
import UserNotifications
@testable import AlertMe

struct NotificationAuthorizationTests {
    @Test
    func onlyAuthorizedStatusesAllowScheduling() {
        #expect(UNAuthorizationStatus.authorized.allowsAlertMeNotifications)
        #expect(UNAuthorizationStatus.provisional.allowsAlertMeNotifications)
        #expect(!UNAuthorizationStatus.notDetermined.allowsAlertMeNotifications)
        #expect(!UNAuthorizationStatus.denied.allowsAlertMeNotifications)
    }

    @Test
    func notificationsNotAllowedGetsSigningGuidance() {
        let error = NSError(
            domain: UNErrorDomain,
            code: UNError.Code.notificationsNotAllowed.rawValue
        )

        #expect(
            NotificationAuthorizationGuidance.message(for: error)
                == NotificationAuthorizationGuidance.unavailableMessage
        )
    }
}
