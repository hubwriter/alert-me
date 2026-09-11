import AppKit
import Combine
import Foundation
import SwiftData
import UserNotifications

@MainActor
final class AlertAppState: NSObject, ObservableObject {
    @Published private(set) var definitions: [AlertDefinition] = []
    @Published private(set) var notificationStatus: UNAuthorizationStatus = .notDetermined
    @Published private(set) var loginItemState: LoginItemState = .disabled
    @Published var lastError: String?

    let modelContainer: ModelContainer
    let settings: AppSettings

    private let context: ModelContext
    private let calculator: RecurrenceCalculator
    private let notificationScheduler: NotificationScheduling
    private let loginItemService: LoginItemServicing
    private let presenter: AlertPresenting
    private var timerTask: Task<Void, Never>?
    private var lifecycleObservers: [(NotificationCenter, NSObjectProtocol)] = []
    private let notificationWindowSize = 32
    private let liveTimerTolerance: TimeInterval = 60
    private var didStart = false

    init(
        modelContainer: ModelContainer,
        settings: AppSettings,
        calculator: RecurrenceCalculator = RecurrenceCalculator(),
        notificationScheduler: NotificationScheduling = NotificationScheduler(),
        loginItemService: LoginItemServicing = LoginItemService(),
        presenter: AlertPresenting? = nil
    ) {
        self.modelContainer = modelContainer
        self.settings = settings
        context = ModelContext(modelContainer)
        self.calculator = calculator
        self.notificationScheduler = notificationScheduler
        self.loginItemService = loginItemService
        let resolvedPresenter = presenter ?? AlertPanelPresenter(settings: settings)
        self.presenter = resolvedPresenter
        super.init()

        resolvedPresenter.onDismiss = { [weak self] alert in
            self?.recordDismissal(alert)
        }
    }

    func start() {
        guard !didStart else {
            return
        }
        didStart = true
        UNUserNotificationCenter.current().delegate = self
        installLifecycleObservers()
        Task {
            await refreshStatuses()
            await reconcile(markElapsedAsMissed: true)
        }
    }

    func add(_ draft: AlertDraft) {
        let now = Date()
        let snapshot = draft.snapshot()
        let definition = AlertDefinition(
            message: draft.message.trimmingCharacters(in: .whitespacesAndNewlines),
            recurrence: draft.recurrence,
            oneTimeDate: snapshot.oneTimeDate,
            startDate: snapshot.startDate,
            hour: snapshot.hour,
            minute: snapshot.minute,
            weekdayMask: snapshot.weekdayMask,
            monthDay: snapshot.monthDay,
            month: snapshot.month,
            isEnabled: draft.isEnabled,
            isSilent: draft.isSilent,
            createdAt: now,
            updatedAt: now
        )
        context.insert(definition)
        saveAndReconcile()
    }

    func update(_ definition: AlertDefinition, with draft: AlertDraft) {
        let snapshot = draft.snapshot(id: definition.id)
        definition.message = draft.message.trimmingCharacters(in: .whitespacesAndNewlines)
        definition.recurrence = draft.recurrence
        definition.oneTimeDate = snapshot.oneTimeDate
        definition.startDate = snapshot.startDate
        definition.hour = snapshot.hour
        definition.minute = snapshot.minute
        definition.weekdayMask = snapshot.weekdayMask
        definition.monthDay = snapshot.monthDay
        definition.month = snapshot.month
        definition.isEnabled = draft.isEnabled
        definition.isSilent = draft.isSilent
        definition.updatedAt = Date()
        definition.lastHandledOccurrence = nil
        definition.lastOutcome = nil
        definition.nextOccurrenceAt = nil
        saveAndReconcile()
    }

    func setEnabled(_ definition: AlertDefinition, enabled: Bool) {
        definition.isEnabled = enabled
        definition.updatedAt = Date()
        saveAndReconcile()
    }

    func delete(_ definition: AlertDefinition) {
        presenter.removeQueued(definitionID: definition.id)
        context.delete(definition)
        saveAndReconcile()
    }

    func requestNotificationAuthorization() {
        Task {
            do {
                let granted = try await notificationScheduler.requestAuthorization()
                await refreshStatuses()
                if granted && notificationStatus.allowsAlertMeNotifications {
                    await reconcile(markElapsedAsMissed: false)
                } else if notificationStatus == .notDetermined {
                    lastError = NotificationAuthorizationGuidance.unavailableMessage
                }
            } catch {
                await refreshStatuses()
                lastError = NotificationAuthorizationGuidance.message(for: error)
            }
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try loginItemService.setEnabled(enabled)
            loginItemState = loginItemService.state
        } catch {
            lastError = error.localizedDescription
            loginItemState = loginItemService.state
        }
    }

    func refreshAuthorizationAfterReturningFromSettings() async {
        let previousStatus = notificationStatus
        await refreshStatuses()
        if notificationStatus.allowsAlertMeNotifications,
           !previousStatus.allowsAlertMeNotifications {
            lastError = nil
            await reconcile(markElapsedAsMissed: false)
        }
    }

    var futureDefinitions: [AlertDefinition] {
        definitions.filter {
            $0.recurrence != .oneTime || ($0.oneTimeDate ?? .distantPast) > Date()
        }
    }

    var pastDefinitions: [AlertDefinition] {
        definitions.filter {
            $0.recurrence == .oneTime && ($0.oneTimeDate ?? .distantPast) <= Date()
        }
    }

    private func saveAndReconcile() {
        do {
            try context.save()
            refreshDefinitions()
            Task {
                await reconcile(markElapsedAsMissed: true)
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func refreshDefinitions() {
        do {
            let descriptor = FetchDescriptor<AlertDefinition>(
                sortBy: [
                    SortDescriptor(\.createdAt),
                    SortDescriptor(\.id)
                ]
            )
            definitions = try context.fetch(descriptor)
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func reconcile(markElapsedAsMissed: Bool) async {
        refreshDefinitions()
        let now = Date()

        for definition in definitions {
            advance(definition, now: now, markElapsedAsMissed: markElapsedAsMissed)
        }

        do {
            try context.save()
        } catch {
            lastError = error.localizedDescription
        }
        refreshDefinitions()

        let upcoming = definitions
            .filter { $0.isEnabled && $0.nextOccurrenceAt != nil }
            .sorted(by: Self.scheduleOrder)
        let descriptors = upcoming.prefix(notificationWindowSize).compactMap { definition in
            definition.nextOccurrenceAt.map {
                NotificationDescriptor(
                    identifier: notificationIdentifier(for: definition.id, occurrence: $0),
                    message: definition.message,
                    deliveryDate: NotificationFallbackPolicy.deliveryDate(for: $0),
                    isSilent: definition.isSilent
                )
            }
        }

        if notificationStatus.allowsAlertMeNotifications {
            do {
                try await notificationScheduler.replaceManagedNotifications(with: descriptors)
            } catch {
                lastError = NotificationAuthorizationGuidance.message(for: error)
            }
        }
        armTimer(for: upcoming.first?.nextOccurrenceAt)
    }

    private func advance(
        _ definition: AlertDefinition,
        now: Date,
        markElapsedAsMissed: Bool
    ) {
        guard definition.isEnabled else {
            definition.nextOccurrenceAt = calculator.nextOccurrence(
                after: now,
                schedule: definition.scheduleSnapshot,
                calendar: .current
            )
            return
        }

        var next = nextOccurrence(for: definition)

        if markElapsedAsMissed {
            while let occurrence = next, occurrence <= now {
                if definition.lastHandledOccurrence == nil || occurrence > definition.lastHandledOccurrence! {
                    definition.lastHandledOccurrence = occurrence
                    definition.lastOutcome = .missed
                    definition.missedCount += 1
                    notificationScheduler.removeDeliveredNotification(
                        identifier: notificationIdentifier(for: definition.id, occurrence: occurrence)
                    )
                }
                next = calculator.nextOccurrence(
                    after: occurrence,
                    schedule: definition.scheduleSnapshot,
                    calendar: .current
                )
            }
        }

        definition.nextOccurrenceAt = next
    }

    private func nextOccurrence(for definition: AlertDefinition) -> Date? {
        if let cached = definition.nextOccurrenceAt {
            let normalizedCached = startOfMinute(cached)
            if definition.lastHandledOccurrence == nil
                || normalizedCached > definition.lastHandledOccurrence! {
                return normalizedCached
            }
        }
        let anchor = definition.lastHandledOccurrence
            ?? definition.startDate.addingTimeInterval(-1)
        return calculator.nextOccurrence(
            after: anchor,
            schedule: definition.scheduleSnapshot,
            calendar: .current
        )
    }

    private func startOfMinute(_ date: Date) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: date
        )
        return calendar.date(from: components) ?? date
    }

    private func armTimer(for date: Date?) {
        timerTask?.cancel()
        guard let date else {
            timerTask = nil
            return
        }
        let delay = max(0, date.timeIntervalSinceNow)
        timerTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay), tolerance: .zero)
            guard !Task.isCancelled else {
                return
            }
            await self?.handleTimer()
        }
    }

    private func handleTimer() async {
        refreshDefinitions()
        let now = Date()
        let dueDefinitions = definitions
            .filter {
                $0.isEnabled
                    && $0.nextOccurrenceAt != nil
                    && $0.nextOccurrenceAt! <= now
            }
            .sorted(by: Self.scheduleOrder)
        var dueAlerts: [DueAlert] = []

        for definition in dueDefinitions {
            guard let occurrence = definition.nextOccurrenceAt,
                  definition.lastHandledOccurrence == nil
                    || occurrence > definition.lastHandledOccurrence! else {
                continue
            }

            definition.lastHandledOccurrence = occurrence
            if now.timeIntervalSince(occurrence) <= liveTimerTolerance {
                definition.lastOutcome = .scheduled
                dueAlerts.append(
                    DueAlert(
                        definitionID: definition.id,
                        occurrence: occurrence,
                        createdAt: definition.createdAt,
                        message: definition.message,
                        isSilent: definition.isSilent
                    )
                )
            } else {
                definition.lastOutcome = .missed
                definition.missedCount += 1
            }
            definition.nextOccurrenceAt = calculator.nextOccurrence(
                after: occurrence,
                schedule: definition.scheduleSnapshot,
                calendar: .current
            )
        }

        do {
            try context.save()
            if presenter.enqueue(dueAlerts) {
                for alert in dueAlerts {
                    let identifier = notificationIdentifier(
                        for: alert.definitionID,
                        occurrence: alert.occurrence
                    )
                    notificationScheduler.removePendingNotification(identifier: identifier)
                    notificationScheduler.removeDeliveredNotification(identifier: identifier)
                }
            }
        } catch {
            lastError = error.localizedDescription
        }
        await reconcile(markElapsedAsMissed: false)
    }

    private func recordDismissal(_ alert: DueAlert) {
        guard let definition = definitions.first(where: { $0.id == alert.definitionID }) else {
            return
        }
        definition.lastOutcome = .dismissed
        definition.lastDismissedAt = Date()
        saveAndReconcile()
    }

    private func refreshStatuses() async {
        notificationStatus = await notificationScheduler.authorizationStatus()
        loginItemState = loginItemService.state
    }

    private func installLifecycleObservers() {
        let workspaceCenter = NSWorkspace.shared.notificationCenter
        let wakeObserver = workspaceCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.reconcile(markElapsedAsMissed: true)
            }
        }
        lifecycleObservers.append((workspaceCenter, wakeObserver))

        let center = NotificationCenter.default
        let activationObserver = center.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.refreshAuthorizationAfterReturningFromSettings()
            }
        }
        lifecycleObservers.append((center, activationObserver))

        let clockObserver = center.addObserver(
            forName: NSNotification.Name.NSSystemClockDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.reconcile(markElapsedAsMissed: true)
            }
        }
        lifecycleObservers.append((center, clockObserver))

        let timeZoneObserver = center.addObserver(
            forName: NSNotification.Name.NSSystemTimeZoneDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else {
                    return
                }
                for definition in self.definitions where definition.recurrence != .oneTime {
                    definition.nextOccurrenceAt = nil
                }
                await self.reconcile(markElapsedAsMissed: true)
            }
        }
        lifecycleObservers.append((center, timeZoneObserver))
    }

    private func notificationIdentifier(for id: UUID, occurrence: Date) -> String {
        "alert.\(id.uuidString).\(Int(occurrence.timeIntervalSince1970))"
    }

    private static func scheduleOrder(_ lhs: AlertDefinition, _ rhs: AlertDefinition) -> Bool {
        (
            lhs.nextOccurrenceAt ?? .distantFuture,
            lhs.createdAt,
            lhs.id.uuidString
        ) < (
            rhs.nextOccurrenceAt ?? .distantFuture,
            rhs.createdAt,
            rhs.id.uuidString
        )
    }
}

extension AlertAppState: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        []
    }
}
