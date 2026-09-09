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
protocol NotificationScheduling {
    func authorizationStatus() async -> UNAuthorizationStatus
    func requestAuthorization() async throws -> Bool
    func replaceManagedNotifications(with descriptors: [NotificationDescriptor]) async throws
    func removePendingNotification(identifier: String)
    func removeDeliveredNotification(identifier: String)
}

@MainActor
final class NotificationScheduler: NotificationScheduling {
    private let center: UNUserNotificationCenter
    private let identifierPrefix = "alert."

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
        let managedIdentifiers: [String] = await withCheckedContinuation { continuation in
            center.getPendingNotificationRequests { requests in
                continuation.resume(
                    returning: requests
                        .map(\.identifier)
                        .filter { $0.hasPrefix(self.identifierPrefix) }
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

    func removePendingNotification(identifier: String) {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    func removeDeliveredNotification(identifier: String) {
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
    }
}
