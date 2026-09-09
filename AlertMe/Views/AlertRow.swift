import SwiftUI

struct AlertRow: View {
    let definition: AlertDefinition
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onEnabledChange: (Bool) -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: definition.isSilent ? "bell.slash.fill" : "bell.fill")
                .font(.title2)
                .foregroundStyle(definition.isEnabled ? Color.accentColor : .secondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 5) {
                Text(definition.message)
                    .font(.headline)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Text(scheduleDescription)
                    if !definition.isEnabled {
                        Text("Disabled")
                            .foregroundStyle(.orange)
                    } else if let outcome = definition.lastOutcome {
                        Text(outcomeDescription(outcome))
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle(
                "Enabled",
                isOn: Binding(
                    get: { definition.isEnabled },
                    set: { enabled in
                        onEnabledChange(enabled)
                    }
                )
            )
            .labelsHidden()

            Button("Edit", systemImage: "pencil", action: onEdit)
                .buttonStyle(.borderless)
                .accessibilityIdentifier("editAlertButton")

            Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
                .buttonStyle(.borderless)
                .accessibilityIdentifier("deleteAlertButton")
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .accessibilityIdentifier("alertRow")
    }

    private var scheduleDescription: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short

        switch definition.recurrence {
        case .oneTime:
            guard let date = definition.oneTimeDate else {
                return "Unscheduled"
            }
            return "\(AlertDisplayDateFormatter.dateString(from: date)) at \(formatter.string(from: date))"
        case .daily:
            return "Every day at \(timeString(formatter))"
        case .weekly:
            let weekdays = Calendar.current.weekdaySymbols.enumerated().compactMap { index, name in
                WeekdayMask.contains(definition.weekdayMask, calendarWeekday: index + 1)
                    ? String(name.prefix(3))
                    : nil
            }
            return "Every \(weekdays.joined(separator: ", ")) at \(timeString(formatter))"
        case .monthly:
            return "Monthly on day \(definition.monthDay) at \(timeString(formatter))"
        case .yearly:
            var components = DateComponents()
            components.month = definition.month
            components.day = definition.monthDay
            let date = Calendar.current.date(from: components)
            let dateText = date.map {
                let dateFormatter = DateFormatter()
                dateFormatter.setLocalizedDateFormatFromTemplate("MMMMd")
                return dateFormatter.string(from: $0)
            } ?? "the selected date"
            return "Every \(dateText) at \(timeString(formatter))"
        }
    }

    private func timeString(_ formatter: DateFormatter) -> String {
        var components = DateComponents()
        components.hour = definition.hour
        components.minute = definition.minute
        return Calendar.current.date(from: components).map(formatter.string(from:)) ?? ""
    }

    private func outcomeDescription(_ outcome: AlertOutcome) -> String {
        switch outcome {
        case .scheduled: "Alerting"
        case .dismissed: "Dismissed"
        case .missed: "Missed"
        }
    }
}
