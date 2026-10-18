import SwiftUI

struct AlertEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AlertAppState

    let definition: AlertDefinition?
    @State private var draft: AlertDraft

    init(definition: AlertDefinition?) {
        self.definition = definition
        _draft = State(initialValue: definition.map(AlertDraft.init(definition:)) ?? AlertDraft())
    }

    var body: some View {
        let validation = AlertValidator().validate(draft, now: Date())
        let minimumEndDate = AlertValidator().minimumEndDate(for: draft, now: Date())

        VStack(alignment: .leading, spacing: 10) {
            Text(definition == nil ? "New Alert" : "Edit Alert")
                .font(.title2.bold())

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Message")
                        .font(.headline)
                    Spacer()
                    Text("\(draft.message.count)/500")
                        .foregroundStyle(draft.message.count > 500 ? .red : .secondary)
                }

                TextEditor(text: $draft.message)
                    .font(.body)
                    .frame(height: 130)
                    .padding(6)
                    .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
                    .accessibilityIdentifier("messageEditor")

                ValidationMessage(validation.messageError ?? " ")
                    .opacity(validation.messageError == nil ? 0 : 1)
                    .accessibilityHidden(validation.messageError == nil)
            }

            Picker("Repeat", selection: $draft.recurrence) {
                ForEach(RecurrenceKind.allCases) {
                    Text($0.title).tag($0)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("recurrencePicker")

            AlertDateTimeControls(
                selection: $draft.scheduledDate,
                weekdayMask: $draft.weekdayMask,
                isWeekdaysOnly: $draft.isWeekdaysOnly,
                recurrence: draft.recurrence
            )

            VStack(alignment: .leading, spacing: 10) {
                if draft.recurrence == .oneTime, let error = validation.scheduleError {
                    ValidationMessage(error)
                }

                HStack {
                    Toggle("Play the alert sound", isOn: silentInvertedBinding)
                        .accessibilityIdentifier("soundToggle")

                    Spacer()
                    if definition != nil {
                        Toggle("Enabled", isOn: $draft.isEnabled)
                    }
                }

                HStack(alignment: .bottom, spacing: 16) {
                    if draft.recurrence != .oneTime {
                        AlertEndDateControls(
                            endDate: $draft.endDate,
                            minimumDate: minimumEndDate ?? Calendar.current.startOfDay(for: draft.scheduledDate)
                        )
                    }
                    Spacer(minLength: 0)

                    VStack(alignment: .trailing, spacing: 6) {
                        if draft.recurrence != .oneTime, let error = validation.scheduleError {
                            ValidationMessage(error)
                        }
                        if let error = validation.endDateError {
                            ValidationMessage(error)
                        }
                        HStack {
                            Button("Cancel") {
                                dismiss()
                            }
                            .keyboardShortcut(.cancelAction)

                            Button("Save") {
                                if let definition {
                                    appState.update(definition, with: draft)
                                } else {
                                    appState.add(draft)
                                }
                                dismiss()
                            }
                            .buttonStyle(.borderedProminent)
                            .keyboardShortcut(.defaultAction)
                            .disabled(!validation.isValid)
                            .accessibilityIdentifier("saveAlertButton")
                        }
                    }
                }
                .frame(maxHeight: .infinity, alignment: .bottom)
            }
        }
        .padding(24)
        .frame(width: 560, height: 460)
        .onChange(of: minimumEndDate) { _, minimumDate in
            if let minimumDate, let endDate = draft.endDate, endDate < minimumDate {
                draft.endDate = minimumDate
            }
        }
    }

    private var silentInvertedBinding: Binding<Bool> {
        Binding(
            get: { !draft.isSilent },
            set: { draft.isSilent = !$0 }
        )
    }
}

private struct ValidationMessage: View {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var body: some View {
        Label(message, systemImage: "exclamationmark.circle.fill")
            .font(.caption)
            .foregroundStyle(.red)
    }
}
