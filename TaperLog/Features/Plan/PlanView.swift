import SwiftUI
import SwiftData

/// The schedule exactly as the prescriber wrote it, one row per step.
struct PlanView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \TaperPlan.createdAt) private var plans: [TaperPlan]
    @Query(sort: \TaperStep.startDate) private var allSteps: [TaperStep]

    @State private var editingPlan = false
    @State private var editingStep: TaperStep?
    @State private var addingStep = false

    private var plan: TaperPlan? { plans.first { $0.isActive } ?? plans.first }
    private var ordered: [TaperStep] { TaperMath.steps(allSteps, for: plan) }

    var body: some View {
        NavigationStack {
            Group {
                if let plan {
                    List {
                        Section {
                            LabeledContent("Medicine", value: plan.medicationName)
                            LabeledContent("Form and unit", value: plan.subtitle)
                            if !plan.prescriberName.isEmpty { LabeledContent("Prescriber", value: plan.prescriberName) }
                            LabeledContent("Started", value: Formatters.date.string(from: plan.startDate))
                            if let end = TaperMath.planEnd(ordered) { LabeledContent("Last scheduled day", value: Formatters.date.string(from: end)) }
                            Button("Edit plan") { editingPlan = true }
                        } footer: {
                            Text("Everything here comes from your prescriber. \(AppConfig.appName) never works out a step or changes one.")
                        }

                        Section {
                            if ordered.isEmpty {
                                Text("No steps yet. Add the first one from your prescription.").foregroundStyle(.secondary)
                            }
                            ForEach(Array(ordered.enumerated()), id: \.element.id) { index, step in
                                Button { editingStep = step } label: { StepRow(step: step, index: index, ordered: ordered, unit: plan.unit) }
                                    .buttonStyle(.plain)
                            }
                            .onDelete { offsets in offsets.map { ordered[$0] }.forEach(context.delete) }
                            Button { addingStep = true } label: { Label("Add Step", systemImage: "plus") }
                        } header: { Text("Schedule") } footer: {
                            Text("Each step runs until the next one starts. The last step uses the length you set.")
                        }

                        if !plan.notes.isEmpty {
                            Section("Notes") { Text(plan.notes).font(.subheadline) }
                        }
                    }
                } else {
                    ContentUnavailableView {
                        Label("No plan yet", systemImage: "pills")
                    } description: {
                        Text("Enter the medicine and the schedule your prescriber gave you.")
                    } actions: {
                        Button("Set Up Plan") { editingPlan = true }.buttonStyle(.borderedProminent)
                    }
                }
            }
            .navigationTitle("Plan")
            .toolbar {
                if plan != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { addingStep = true } label: { Image(systemName: "plus") }.accessibilityLabel("Add step")
                    }
                }
            }
            .sheet(isPresented: $editingPlan) { PlanEditorView(plan: plan) }
            .sheet(item: $editingStep) { step in
                if let plan { StepEditorView(plan: plan, step: step, ordered: ordered) }
            }
            .sheet(isPresented: $addingStep) {
                if let plan { StepEditorView(plan: plan, step: nil, ordered: ordered) }
            }
        }
    }
}

struct StepRow: View {
    let step: TaperStep
    let index: Int
    let ordered: [TaperStep]
    let unit: DoseUnit

    var body: some View {
        let range = TaperMath.range(of: step, in: ordered)
        let isCurrent = TaperMath.step(on: .now, in: ordered)?.id == step.id
        return HStack(spacing: 12) {
            ZStack {
                Circle().fill(isCurrent ? Color.accentColor : Color.secondary.opacity(0.18)).frame(width: 30, height: 30)
                Text("\(index + 1)").font(.subheadline.weight(.bold)).foregroundStyle(isCurrent ? .white : .secondary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(step.doseSummary(unit: unit)).font(.subheadline.weight(.semibold))
                Text("\(Formatters.short.string(from: range.start)) to \(Formatters.short.string(from: range.end)) · \(Formatters.dose(step.dailyTotal, unit: unit)) a day")
                    .font(.caption).foregroundStyle(.secondary)
                if !step.notes.isEmpty { Text(step.notes).font(.caption).foregroundStyle(.secondary).lineLimit(1) }
            }
            Spacer()
            if isCurrent {
                Text("Now").font(.caption2.weight(.bold)).padding(.horizontal, 7).padding(.vertical, 3)
                    .background(Color.accentColor.opacity(0.15), in: Capsule()).foregroundStyle(Color.accentColor)
            }
        }
        .contentShape(Rectangle())
    }
}
