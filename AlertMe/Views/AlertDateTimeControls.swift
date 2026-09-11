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
                        TextField("DD/MM/YYYY", value: dateBinding, formatter: Self.dateFormatter)
                            .frame(width: 112)
                            .accessibilityIdentifier("alertDateField")
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
                    TextField("Time", value: timeBinding, formatter: Self.timeFormatter)
                        .frame(width: 96)
                        .accessibilityIdentifier("alertTimeField")
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
