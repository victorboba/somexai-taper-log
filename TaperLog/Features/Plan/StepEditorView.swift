import SwiftUI
import SwiftData

/// One step of the schedule. Every amount is typed in by the user.
/// A new step copies the previous step's times and amounts so only the numbers that changed need editing;
/// the app never lowers a dose by itself.
struct StepEditorView: View {
    let plan: TaperPlan
    let step: TaperStep?
    let ordered: [TaperStep]

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var startDate: Date = .now
    @State private var durationDays = 14
    @State private var slots: [DoseSlot] = []
    @State private var notes = ""
    @State private var newLabel = ""

    private var dailyTotal: Double { slots.reduce(0) { $0 + $1.amount } }
    private var isLast: Bool { step == nil || step?.id == ordered.last?.id }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Starts", selection: $startDate, displayedComponents: .date)
                    if isLast {
                        Stepper("Lasts \(durationDays) day\(durationDays == 1 ? "" : "s")", value: $durationDays, in: 1...365)
                    }
                } header: { Text("When") } footer: {
                    Text(isLast ? "The last step runs for the length you set here."
                                : "This step runs until the next one starts. Change the next step's start date to make it longer or shorter.")
                }

                Section {
                    ForEach($slots) { $slot in
                        HStack {
                            TextField("Time of day", text: $slot.label)
                                .frame(maxWidth: 150)
                            Spacer()
                            TextField("0", value: $slot.amount, format: .number.precision(.fractionLength(0...3)))
                                .keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 80)
                                .accessibilityLabel("Amount for \(slot.label)")
                            Text(plan.unit.rawValue).foregroundStyle(.secondary).frame(width: 44, alignment: .leading)
                        }
                    }
                    .onDelete { slots.remove(atOffsets: $0) }
                    Menu {
                        ForEach(DoseSlot.commonLabels, id: \.self) { label in
                            Button(label) { slots.append(DoseSlot(label: label, amount: slots.last?.amount ?? 0)) }
                        }
                        Button("Another time…") { slots.append(DoseSlot(label: "Dose \(slots.count + 1)", amount: 0)) }
                    } label: {
                        Label("Add a time of day", systemImage: "plus")
                    }
                } header: { Text("Doses at this step") } footer: {
                    Text(slots.isEmpty ? "Add each time of day your prescription lists, with the amount for each."
                                       : "Daily total \(Formatters.dose(dailyTotal, unit: plan.unit)). Type the amounts exactly as they are written on your schedule.")
                }

                Section("Note") {
                    TextField("Anything your prescriber said about this step", text: $notes, axis: .vertical).lineLimit(2...5)
                }
            }
            .navigationTitle(step == nil ? "Add Step" : "Edit Step")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() }.bold().disabled(slots.isEmpty) }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        if let step {
            startDate = step.startDate
            durationDays = step.durationDays
            slots = step.doses
            notes = step.notes
        } else if let previous = ordered.last {
            // Copy the shape of the previous step so only the changed numbers need typing.
            let range = TaperMath.range(of: previous, in: ordered)
            startDate = Calendar.current.date(byAdding: .day, value: 1, to: range.end) ?? .now
            durationDays = previous.durationDays
            slots = previous.doses
        } else {
            startDate = plan.startDate
            slots = [DoseSlot(label: "Morning", amount: 0)]
        }
    }

    private func save() {
        let cleaned = slots.filter { !$0.label.trimmingCharacters(in: .whitespaces).isEmpty }
        let target = step ?? TaperStep(planID: plan.id, orderIndex: ordered.count, startDate: startDate)
        target.planID = plan.id
        target.startDate = Calendar.current.startOfDay(for: startDate)
        target.durationDays = durationDays
        target.doses = cleaned
        target.notes = notes
        if step == nil {
            target.orderIndex = ordered.count
            context.insert(target)
        }
        dismiss()
    }
}
