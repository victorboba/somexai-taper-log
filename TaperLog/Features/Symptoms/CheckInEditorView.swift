import SwiftUI
import SwiftData

/// The daily check-in: the common symptoms first, the rest behind a disclosure.
struct CheckInEditorView: View {
    let plan: TaperPlan
    let existing: SymptomCheckIn?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.requestReview) private var requestReview

    @State private var day: Date = .now
    @State private var ratings: [Symptom: Int] = [:]
    @State private var overall = 0
    @State private var sleepHours: Double? = nil
    @State private var notes = ""
    @State private var showingAll = false

    private var others: [Symptom] { Symptom.allCases.filter { !Symptom.common.contains($0) } }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Day", selection: $day, displayedComponents: .date)
                }
                Section {
                    VStack(spacing: 4) {
                        HStack {
                            Text("How was today overall?").font(.subheadline)
                            Spacer()
                            Text(overall == 0 ? "not answered" : "\(overall) of 10")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Slider(value: Binding(get: { Double(overall) }, set: { overall = Int($0.rounded()) }), in: 0...10, step: 1)
                            .accessibilityLabel("Overall, 0 to 10")
                        HStack {
                            Text("rough").font(.caption2).foregroundStyle(.secondary)
                            Spacer()
                            Text("good").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    LabeledContent("Hours of sleep") {
                        TextField("—", value: $sleepHours, format: .number.precision(.fractionLength(0...1)))
                            .keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 70)
                            .accessibilityLabel("Hours of sleep")
                    }
                }
                Section("How bad was each of these?") {
                    ForEach(Symptom.common) { symptom in
                        SeverityPicker(symptom: symptom, value: Binding(
                            get: { ratings[symptom] ?? 0 },
                            set: { ratings[symptom] = $0 }
                        ))
                    }
                }
                Section {
                    DisclosureGroup("More symptoms", isExpanded: $showingAll) {
                        ForEach(others) { symptom in
                            SeverityPicker(symptom: symptom, value: Binding(
                                get: { ratings[symptom] ?? 0 },
                                set: { ratings[symptom] = $0 }
                            ))
                        }
                    }
                }
                Section("Note") {
                    TextField("What happened today", text: $notes, axis: .vertical).lineLimit(2...6)
                }
                Section {
                    Text("If something feels severe or frightening, contact your prescriber or seek urgent care. This app only keeps a record.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle(existing == nil ? "Check In" : "Edit Check-In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() }.bold() }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
                }
            }
            .onAppear {
                guard let existing else { return }
                day = existing.day
                ratings = existing.ratings
                overall = existing.overall
                sleepHours = existing.sleepHours
                notes = existing.notes
                showingAll = others.contains { (existing.ratings[$0] ?? 0) > 0 }
            }
        }
    }

    private func save() {
        let target = existing ?? SymptomCheckIn(plan: plan, day: day)
        target.day = Calendar.current.startOfDay(for: day)
        target.ratings = ratings
        target.overall = overall
        target.sleepHours = sleepHours
        target.notes = notes
        if existing == nil { context.insert(target) }
        ReviewPrompter.recordSuccess(request: requestReview)
        dismiss()
    }
}
