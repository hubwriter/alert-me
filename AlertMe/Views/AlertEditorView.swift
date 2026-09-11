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

        VStack(alignment: .leading, spacing: 20) {
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
                    .frame(minHeight: 110)
                    .padding(6)
                    .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
                    .accessibilityIdentifier("messageEditor")

                if let error = validation.messageError {
                    ValidationMessage(error)
                }
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
                recurrence: draft.recurrence
            )

            if let error = validation.scheduleError {
                ValidationMessage(error)
            }

            Toggle("Play the alert sound", isOn: silentInvertedBinding)
                .accessibilityIdentifier("soundToggle")

            if definition != nil {
                Toggle("Enabled", isOn: $draft.isEnabled)
            }

            Spacer()

            HStack {
                Spacer()
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
        .padding(24)
        .frame(width: 560)
        .frame(minHeight: 500)
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
