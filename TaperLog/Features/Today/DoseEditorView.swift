import SwiftUI
import SwiftData

/// Correct one recorded dose: status, how much was actually taken, when, and a note.
struct DoseEditorView: View {
    let log: DoseLog
    let unit: DoseUnit

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var status: DoseStatus = .taken
    @State private var actual: Double? = nil
    @State private var takenAt: Date = .now
    @State private var hasTime = true
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Dose", value: "\(log.slotLabel) · \(Formatters.dose(log.plannedAmount, unit: unit)) scheduled")
                    Picker("Status", selection: $status) {
                        ForEach(DoseStatus.allCases) { Text($0.name).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                if status != .skipped {
                    Section {
                        LabeledContent("Amount taken") {
                            HStack(spacing: 4) {
                                TextField("0", value: $actual, format: .number.precision(.fractionLength(0...3)))
                                    .keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 80)
                                    .accessibilityLabel("Amount taken")
                                Text(unit.rawValue).foregroundStyle(.secondary)
                            }
                        }
                        Toggle("Record the time", isOn: $hasTime)
                        if hasTime { DatePicker("Taken at", selection: $takenAt) }
                    } footer: {
                        Text("Write down what you actually took, even if it was not what the schedule said. Your prescriber needs the real numbers.")
                    }
                }
                Section("Note") {
                    TextField("Anything worth telling your prescriber", text: $notes, axis: .vertical).lineLimit(2...5)
                }
                Section {
                    Button("Remove this record", role: .destructive) {
                        context.delete(log)
                        dismiss()
                    }
                }
            }
            .navigationTitle("Edit Dose")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() }.bold() }
            }
            .onAppear {
                status = log.status
                actual = log.actualAmount
                hasTime = log.takenAt != nil
                takenAt = log.takenAt ?? .now
                notes = log.notes
            }
            .onChange(of: status) { _, new in
                if new == .taken { actual = log.plannedAmount }
                if new == .skipped { actual = 0 }
            }
        }
    }

    private func save() {
        log.status = status
        log.actualAmount = status == .skipped ? 0 : (actual ?? 0)
        log.takenAt = status == .skipped ? nil : (hasTime ? takenAt : nil)
        log.notes = notes
        dismiss()
    }
}
