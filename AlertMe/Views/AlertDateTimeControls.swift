import SwiftUI

struct AlertDateTimeControls: View {
    @Binding var selection: Date

    var body: some View {
        HStack(alignment: .bottom, spacing: 16) {
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

            Button("Now") {
                selection = AlertDateEditing.startOfMinute(Date())
            }
            .accessibilityIdentifier("alertNowButton")
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
