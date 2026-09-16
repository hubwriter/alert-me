import AppKit
import SwiftUI

struct AlertDateTimeControls: View {
    @Binding var selection: Date
    @Binding var weekdayMask: Int
    let recurrence: RecurrenceKind

    var body: some View {
        HStack(alignment: .bottom, spacing: 16) {
            if recurrence == .weekly {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Day")
                        .font(.headline)
                    Picker("Day", selection: weekdayBinding) {
                        ForEach(WeekdayMask.calendarWeekdaysMondayFirst, id: \.self) { weekday in
                            Text(Calendar.current.weekdaySymbols[weekday - 1])
                                .tag(weekday)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 140)
                    .accessibilityIdentifier("alertWeekdayPicker")
                }
            } else if recurrence != .daily {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Date")
                        .font(.headline)
                    HStack(spacing: 6) {
                        ArrowSteppingDateField(
                            selection: $selection,
                            formatter: Self.dateFormatter,
                            components: [.day, .month, .year],
                            accessibilityIdentifier: "alertDateField"
                        )
                            .frame(width: 112)
                        Stepper(
                            "Change date",
                            onIncrement: {
                                selection = AlertDateEditing.addingDays(1, to: selection)
                            },
                            onDecrement: {
                                selection = AlertDateEditing.addingDays(-1, to: selection)
                            }
                        )
                        .labelsHidden()
                        .accessibilityIdentifier("alertDateStepper")

                        if recurrence == .oneTime {
                            WeekdayLabel(date: selection)
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Time")
                    .font(.headline)
                HStack(spacing: 6) {
                    ArrowSteppingDateField(
                        selection: $selection,
                        formatter: Self.timeFormatter,
                        components: [.hour, .minute],
                        accessibilityIdentifier: "alertTimeField"
                    )
                        .frame(width: 96)
                    Stepper(
                        "Change time",
                        onIncrement: {
                            selection = AlertDateEditing.addingMinutes(1, to: selection)
                        },
                        onDecrement: {
                            selection = AlertDateEditing.addingMinutes(-1, to: selection)
                        }
                    )
                    .labelsHidden()
                    .accessibilityIdentifier("alertTimeStepper")
                }
            }

            if recurrence != .daily {
                Button("Now") {
                    selection = AlertDateEditing.startOfMinute(Date())
                }
                .accessibilityIdentifier("alertNowButton")
            }
        }
    }

    private var dateBinding: Binding<Date> {
        Binding(
            get: { selection },
            set: {
                selection = AlertDateEditing.replacingDate(in: selection, with: $0)
            }
        )
    }

    private var timeBinding: Binding<Date> {
        Binding(
            get: { selection },
            set: {
                selection = AlertDateEditing.replacingTime(in: selection, with: $0)
            }
        )
    }

    private var weekdayBinding: Binding<Int> {
        Binding(
            get: {
                WeekdayMask.calendarWeekdaysMondayFirst.first {
                    WeekdayMask.contains(weekdayMask, calendarWeekday: $0)
                } ?? Calendar.current.component(.weekday, from: Date())
            },
            set: {
                weekdayMask = WeekdayMask.value(for: $0)
            }
        )
    }

    static func weekdayName(for date: Date, calendar: Calendar = .current) -> String {
        calendar.weekdaySymbols[calendar.component(.weekday, from: date) - 1]
    }

    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "dd/MM/yyyy"
        formatter.isLenient = false
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        formatter.isLenient = false
        return formatter
    }()
}

private struct ArrowSteppingDateField: NSViewRepresentable {
    @Binding var selection: Date
    let formatter: DateFormatter
    let components: [AlertDateComponent]
    let accessibilityIdentifier: String

    func makeCoordinator() -> Coordinator {
        Coordinator(
            selection: $selection,
            formatter: formatter,
            components: components
        )
    }

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.delegate = context.coordinator
        field.formatter = formatter
        field.objectValue = selection
        field.identifier = NSUserInterfaceItemIdentifier(accessibilityIdentifier)
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        context.coordinator.selection = $selection
        if field.currentEditor() == nil {
            field.objectValue = selection
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSTextFieldDelegate {
        var selection: Binding<Date>
        private let formatter: DateFormatter
        private let components: [AlertDateComponent]

        init(
            selection: Binding<Date>,
            formatter: DateFormatter,
            components: [AlertDateComponent]
        ) {
            self.selection = selection
            self.formatter = formatter
            self.components = components
        }

        func control(
            _ control: NSControl,
            textView: NSTextView,
            doCommandBy commandSelector: Selector
        ) -> Bool {
            let amount: Int
            switch commandSelector {
            case #selector(NSResponder.moveUp(_:)):
                amount = 1
            case #selector(NSResponder.moveDown(_:)):
                amount = -1
            default:
                return false
            }

            let caretLocation = textView.selectedRange().location
            guard let component = AlertDateEditing.component(
                atCaretLocation: caretLocation,
                in: textView.string,
                components: components
            ) else {
                return false
            }

            selection.wrappedValue = AlertDateEditing.stepping(
                component,
                by: amount,
                in: selection.wrappedValue
            )
            textView.string = formatter.string(from: selection.wrappedValue)
            textView.setSelectedRange(
                NSRange(location: min(caretLocation, textView.string.utf16.count), length: 0)
            )
            return true
        }

        func controlTextDidEndEditing(_ notification: Notification) {
            guard let field = notification.object as? NSTextField,
                  let date = field.objectValue as? Date else {
                return
            }
            if components.contains(.day) {
                selection.wrappedValue = AlertDateEditing.replacingDate(
                    in: selection.wrappedValue,
                    with: date
                )
            } else {
                selection.wrappedValue = AlertDateEditing.replacingTime(
                    in: selection.wrappedValue,
                    with: date
                )
            }
        }
    }
}

private struct WeekdayLabel: View {
    let date: Date

    var body: some View {
        ZStack(alignment: .leading) {
            ForEach(Array(Calendar.current.weekdaySymbols.enumerated()), id: \.offset) {
                _,
                weekday in
                Text(weekday)
                    .hidden()
            }

            Text(AlertDateTimeControls.weekdayName(for: date))
                .lineLimit(1)
                .accessibilityIdentifier("alertSelectedWeekday")
        }
        .fixedSize(horizontal: true, vertical: false)
    }
}
