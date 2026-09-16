import Foundation
@preconcurrency import UserNotifications

struct NotificationDescriptor: Equatable, Sendable {
    let identifier: String
    let message: String
    let deliveryDate: Date
    let isSilent: Bool
}

enum NotificationFallbackPolicy {
    static let delay: TimeInterval = 10

    static func deliveryDate(for occurrence: Date) -> Date {
        occurrence.addingTimeInterval(delay)
    }
}

extension UNAuthorizationStatus {
    var allowsAlertMeNotifications: Bool {
        self == .authorized || self == .provisional
    }
}

enum NotificationAuthorizationGuidance {
    static let unavailableMessage = """
    macOS could not register this build for notifications. In Xcode, add your Apple ID under Settings > Accounts, select the AlertMe target, choose your Development Team under Signing & Capabilities, then rebuild and reinstall the app.
    """

    static func message(for error: any Error) -> String {
        let nsError = error as NSError
        if nsError.domain == UNErrorDomain,
           nsError.code == UNError.Code.notificationsNotAllowed.rawValue {
            return unavailableMessage
        }
        return error.localizedDescription
    }
}

@MainActor
final class NotificationMutationQueue {
    private var pendingMutation: Task<Void, any Error>?

    func perform(
        _ mutation: @escaping @MainActor () async throws -> Void
    ) async throws {
        let previousMutation = pendingMutation
        let task = Task { @MainActor in
            if let previousMutation {
                _ = try? await previousMutation.value
            }
            try await mutation()
        }
        pendingMutation = task
        try await task.value
    }
}

@MainActor
protocol NotificationScheduling {
    func authorizationStatus() async -> UNAuthorizationStatus
    func requestAuthorization() async throws -> Bool
    func replaceManagedNotifications(with descriptors: [NotificationDescriptor]) async throws
    func removePendingNotification(identifier: String) async
    func removeDeliveredNotification(identifier: String)
}

@MainActor
final class NotificationScheduler: NotificationScheduling {
    private let center: UNUserNotificationCenter
    private let identifierPrefix = "alert."
    private let mutationQueue = NotificationMutationQueue()

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await withCheckedContinuation { continuation in
            center.getNotificationSettings {
                continuation.resume(returning: $0.authorizationStatus)
            }
        }
    }

    func requestAuthorization() async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            center.requestAuthorization(options: [.alert, .sound]) { granted, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    func replaceManagedNotifications(with descriptors: [NotificationDescriptor]) async throws {
        try await mutationQueue.perform { [center, identifierPrefix] in
            try await Self.replaceManagedNotifications(
                with: descriptors,
                center: center,
                identifierPrefix: identifierPrefix
            )
        }
    }

    func removePendingNotification(identifier: String) async {
        _ = try? await mutationQueue.perform { [center] in
            center.removePendingNotificationRequests(withIdentifiers: [identifier])
        }
    }

    func removeDeliveredNotification(identifier: String) {
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
    }

    private static func replaceManagedNotifications(
        with descriptors: [NotificationDescriptor],
        center: UNUserNotificationCenter,
        identifierPrefix: String
    ) async throws {
        let managedIdentifiers: [String] = await withCheckedContinuation { continuation in
            center.getPendingNotificationRequests { requests in
                continuation.resume(
                    returning: requests
                        .map(\.identifier)
                        .filter { $0.hasPrefix(identifierPrefix) }
                )
            }
        }
        center.removePendingNotificationRequests(withIdentifiers: managedIdentifiers)

        for descriptor in descriptors {
            let content = UNMutableNotificationContent()
            content.title = "Alert Me"
            content.body = descriptor.message
            content.sound = descriptor.isSilent ? nil : .default
            content.interruptionLevel = .timeSensitive

            var components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: descriptor.deliveryDate
            )
            components.calendar = Calendar.current
            components.timeZone = Calendar.current.timeZone
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(
                identifier: descriptor.identifier,
                content: content,
                trigger: trigger
            )
            let _: Void = try await withCheckedThrowingContinuation {
                (continuation: CheckedContinuation<Void, any Error>) in
                center.add(request) { error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            }
        }
    }
}
