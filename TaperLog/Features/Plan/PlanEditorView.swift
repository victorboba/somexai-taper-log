import SwiftUI
import SwiftData

struct PlanEditorView: View {
    let plan: TaperPlan?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var medicationName = ""
    @State private var form: MedicationForm = .tablet
    @State private var unit: DoseUnit = .mg
    @State private var prescriberName = ""
    @State private var clinicName = ""
    @State private var startDate: Date = .now
    @State private var reason = ""
    @State private var notes = ""
    @State private var isArchived = false
    @State private var completed = false
    @FocusState private var nameFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Medicine name", text: $medicationName).focused($nameFocused)
                    Picker("Form", selection: $form) { ForEach(MedicationForm.allCases) { Text($0.name).tag($0) } }
                    Picker("Measured in", selection: $unit) { ForEach(DoseUnit.allCases) { Text($0.rawValue).tag($0) } }
                    DatePicker("Taper started", selection: $startDate, displayedComponents: .date)
                } footer: {
                    Text("Use the units on the prescription, so the numbers you type match what you were told.")
                }
                Section("Prescriber") {
                    TextField("Prescriber name", text: $prescriberName)
                    TextField("Clinic or practice", text: $clinicName)
                }
                Section("Notes") {
                    TextField("Why you are tapering (optional)", text: $reason)
                    TextField("Anything else to remember", text: $notes, axis: .vertical).lineLimit(2...6)
                }
                if plan != nil {
                    Section {
                        Toggle("Taper finished", isOn: $completed)
                        Toggle("Archived", isOn: $isArchived)
                    } footer: { Text("Archiving keeps everything you have logged and takes the plan off Today.") }
                }
                Section {
                    Text(AppConfig.disclaimer).font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle(plan == nil ? "Set Up Plan" : "Edit Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.bold().disabled(medicationName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let plan {
                    medicationName = plan.medicationName; form = plan.form; unit = plan.unit
                    prescriberName = plan.prescriberName; clinicName = plan.clinicName; startDate = plan.startDate
                    reason = plan.reason; notes = plan.notes; isArchived = plan.isArchived; completed = plan.completedDate != nil
                } else {
                    nameFocused = true
                }
            }
        }
    }

    private func save() {
        let target = plan ?? TaperPlan(medicationName: medicationName)
        target.medicationName = medicationName.trimmingCharacters(in: .whitespaces)
        target.form = form
        target.unit = unit
        target.prescriberName = prescriberName
        target.clinicName = clinicName
        target.startDate = Calendar.current.startOfDay(for: startDate)
        target.reason = reason
        target.notes = notes
        target.isArchived = isArchived
        if completed, target.completedDate == nil { target.completedDate = .now }
        if !completed { target.completedDate = nil }
        if plan == nil { context.insert(target) }
        dismiss()
    }
}
