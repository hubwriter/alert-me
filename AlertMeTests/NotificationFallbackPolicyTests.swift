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

    @Test
    @MainActor
    func pendingNotificationMutationsRunInRequestOrder() async {
        let queue = NotificationMutationQueue()
        let events = NotificationMutationEvents()

        async let replace: Void = queue.perform {
            try await Task.sleep(for: .milliseconds(50))
            events.values.append("replace")
        }
        async let remove: Void = queue.perform {
            events.values.append("remove")
        }

        _ = try? await (replace, remove)

        #expect(events.values == ["replace", "remove"])
    }
}

@MainActor
private final class NotificationMutationEvents {
    var values: [String] = []
}
