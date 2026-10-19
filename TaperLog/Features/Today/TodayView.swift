import SwiftUI
import SwiftData

/// Home: which step you are on, the doses due today, and the daily check-in prompt.
struct TodayView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.requestReview) private var requestReview
    @Query(sort: \TaperPlan.createdAt) private var plans: [TaperPlan]
    @Query(sort: \TaperStep.startDate) private var allSteps: [TaperStep]
    @Query(sort: \DoseLog.day, order: .reverse) private var logs: [DoseLog]
    @Query(sort: \SymptomCheckIn.day, order: .reverse) private var checkIns: [SymptomCheckIn]

    @State private var editingPlan = false
    @State private var showingSettings = false
    @State private var editingLog: DoseLog?
    @State private var checkingIn = false

    private var plan: TaperPlan? { plans.first { $0.isActive } ?? plans.first }
    private var ordered: [TaperStep] { TaperMath.steps(allSteps, for: plan) }
    private var today: Date { Calendar.current.startOfDay(for: .now) }
    private var slots: [DoseSlot] { TaperMath.scheduledDoses(on: today, in: ordered) }
    private var todayLogs: [DoseLog] { TaperMath.logs(logs.filter { $0.planID == plan?.id }, on: today) }
    private var todayCheckIn: SymptomCheckIn? { checkIns.first { $0.planID == plan?.id && Calendar.current.isDate($0.day, inSameDayAs: today) } }

    var body: some View {
        NavigationStack {
            ScrollView {
                if let plan, !ordered.isEmpty {
                    VStack(spacing: 14) {
                        stepCard(plan)
                        dosesCard(plan)
                        checkInCard
                        Text(AppConfig.disclaimer).font(.footnote).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding()
                } else if plan != nil {
                    ContentUnavailableView {
                        Label("Add the steps", systemImage: "list.number")
                    } description: {
                        Text("Type in the schedule your prescriber gave you on the Plan tab, one step per reduction.")
                    }
                    .padding(.top, 60)
                } else {
                    ContentUnavailableView {
                        Label("Set up your plan", systemImage: "pills")
                    } description: {
                        Text("Enter the medicine and the schedule your prescriber wrote down. The app records it; it never works one out.")
                    } actions: {
                        Button("Set Up Plan") { editingPlan = true }.buttonStyle(.borderedProminent)
                    }
                    .padding(.top, 60)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Today")
            .toolbar {
                ToolbarItemGroup(placement: .topBarLeading) {
                    Button { showingSettings = true } label: { Image(systemName: "gearshape") }.accessibilityLabel("Settings")
                    NavigationLink { HowToView() } label: { Image(systemName: "questionmark.circle") }.accessibilityLabel("How do I use this app")
                }
            }
            .sheet(isPresented: $editingPlan) { PlanEditorView(plan: nil) }
            .sheet(isPresented: $showingSettings) { SettingsView() }
            .sheet(item: $editingLog) { DoseEditorView(log: $0, unit: plan?.unit ?? .mg) }
            .sheet(isPresented: $checkingIn) { if let plan { CheckInEditorView(plan: plan, existing: todayCheckIn) } }
        }
        .task {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-sampleData"), plans.isEmpty { SampleData.insert(into: context) }
            #endif
        }
        .onChange(of: logs.count, initial: true) { sync() }
        .onChange(of: allSteps.count) { sync() }
        .onChange(of: checkIns.count) { sync() }
        .onChange(of: scenePhase, initial: true) { _, phase in
            guard phase == .active else { return }
            WidgetSnapshot.defaults.removeObject(forKey: LogDoseIntent.pendingKey)
        }
    }

    private func sync() {
        WidgetSync.update(plan: plan, steps: allSteps, logs: logs, checkIns: checkIns)
        let p = plan, s = allSteps
        Task { await DoseReminder.reschedule(plan: p, steps: s) }
    }

    // MARK: Cards

    private func stepCard(_ plan: TaperPlan) -> some View {
        let progress = TaperMath.progress(ordered)
        return Panel {
            HStack(alignment: .firstTextBaseline) {
                Text(plan.medicationName).font(.title3.weight(.semibold))
                Spacer()
                if progress.stepCount > 0, progress.stepNumber > 0 {
                    Text("Step \(progress.stepNumber) of \(progress.stepCount)").font(.subheadline).foregroundStyle(.secondary)
                }
            }
            if let current = progress.current {
                Text(current.doseSummary(unit: plan.unit))
                    .font(.system(size: 30, weight: .bold, design: .rounded)).monospacedDigit()
                Text("\(Formatters.dose(current.dailyTotal, unit: plan.unit)) a day · day \(progress.dayInStep) of \(progress.daysInStep)")
                    .font(.subheadline).foregroundStyle(.secondary)
                ProgressView(value: progress.stepFraction).tint(.accentColor)
                if let days = progress.daysToNextStep, let date = progress.nextStepDate, let next = progress.nextStep {
                    Text(days <= 0 ? "Next step starts today: \(next.doseSummary(unit: plan.unit))"
                                   : "Next step in \(Formatters.days(days)), on \(Formatters.short.string(from: date)): \(next.doseSummary(unit: plan.unit))")
                        .font(.caption).foregroundStyle(.secondary)
                } else if let end = progress.planEnd {
                    Text("Last scheduled day \(Formatters.date.string(from: end))").font(.caption).foregroundStyle(.secondary)
                }
            } else if progress.hasFinished {
                Text("The schedule has finished").font(.headline)
                Text("Nothing is scheduled after \(progress.planEnd.map(Formatters.date.string(from:)) ?? "the last step"). Talk to your prescriber about what comes next.")
                    .font(.subheadline).foregroundStyle(.secondary)
            } else {
                Text("Starts \(Formatters.date.string(from: ordered[0].startDate))").font(.headline)
                Text("Nothing is due until then.").font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }

    private func dosesCard(_ plan: TaperPlan) -> some View {
        Panel(title: "Today's doses") {
            if slots.isEmpty {
                Text("No doses are scheduled today.").font(.subheadline).foregroundStyle(.secondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(slots.enumerated()), id: \.element.id) { index, slot in
                        DoseRow(slot: slot, unit: plan.unit,
                                log: todayLogs.first { $0.slotLabel == slot.label },
                                onSet: { mark(slot: slot, status: $0, plan: plan) },
                                onOpen: { editingLog = todayLogs.first { $0.slotLabel == slot.label } })
                            .padding(.vertical, 10)
                        if index < slots.count - 1 { Divider() }
                    }
                }
                let done = slots.filter { slot in todayLogs.contains { $0.slotLabel == slot.label } }.count
                Text("\(done) of \(slots.count) recorded").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var checkInCard: some View {
        Panel(title: "Daily check-in") {
            if let checkIn = todayCheckIn, checkIn.hasContent {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Label("Done for today", systemImage: "checkmark.circle.fill").font(.subheadline.weight(.semibold)).foregroundStyle(.green)
                        if let worst = checkIn.worst {
                            Text("Worst: \(worst.symptom.name.lowercased()), \(Severity(rawValue: worst.value)?.name.lowercased() ?? "")")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        if checkIn.overall > 0 { Text("Overall \(checkIn.overall) of 10").font(.caption).foregroundStyle(.secondary) }
                    }
                    Spacer()
                    Button("Edit") { checkingIn = true }
                }
            } else {
                Text("Rate how today has been. It takes under a minute and builds the chart your prescriber sees.")
                    .font(.subheadline).foregroundStyle(.secondary)
                Button { checkingIn = true } label: {
                    Label("Check In", systemImage: "waveform.path.ecg").font(.headline).frame(maxWidth: .infinity).frame(height: 44)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private func mark(slot: DoseSlot, status: DoseStatus, plan: TaperPlan) {
        let step = TaperMath.step(on: today, in: ordered)
        let log = DoseLog(plan: plan, step: step, day: today, slot: slot, status: status)
        if status == .partial { log.actualAmount = slot.amount / 2 }
        context.insert(log)
        UINotificationFeedbackGenerator().notificationOccurred(status == .taken ? .success : .warning)
        ReviewPrompter.recordSuccess(request: requestReview)
        if status == .partial { editingLog = log }
    }
}
