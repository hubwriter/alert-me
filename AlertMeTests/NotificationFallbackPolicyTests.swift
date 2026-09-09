import Foundation
import Testing
@testable import AlertMe

struct NotificationFallbackPolicyTests {
    @Test
    func fallbackDeliveryWaitsForPopupToPresent() {
        let occurrence = Date(timeIntervalSince1970: 1_000)

        #expect(
            NotificationFallbackPolicy.deliveryDate(for: occurrence)
                == Date(timeIntervalSince1970: 1_010)
        )
    }
}
