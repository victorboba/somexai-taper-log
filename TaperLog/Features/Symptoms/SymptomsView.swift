import SwiftUI
import SwiftData

/// The daily check-ins, charted against the step changes.
struct SymptomsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \TaperPlan.createdAt) private var plans: [TaperPlan]
    @Query(sort: \TaperStep.startDate) private var allSteps: [TaperStep]
    @Query(sort: \SymptomCheckIn.day, order: .reverse) private var checkIns: [SymptomCheckIn]

    @State private var editing: SymptomCheckIn?
    @State private var checkingIn = false
    @State private var chosen: Set<Symptom> = []

    private var plan: TaperPlan? { plans.first { $0.isActive } ?? plans.first }
    private var ordered: [TaperStep] { TaperMath.steps(allSteps, for: plan) }
    private var mine: [SymptomCheckIn] { checkIns.filter { $0.planID == plan?.id && $0.hasContent } }
    private var ranked: [(symptom: Symptom, average: Double, days: Int)] { TaperMath.rankedSymptoms(mine) }
    private var charted: [Symptom] { chosen.isEmpty ? TaperMath.mostTracked(mine) : Array(chosen) }
    private var todayCheckIn: SymptomCheckIn? { mine.first { Calendar.current.isDateInToday($0.day) } }

    var body: some View {
        NavigationStack {
            Group {
                if plan == nil {
                    ContentUnavailableView("No plan yet", systemImage: "waveform.path.ecg", description: Text("Set the plan up on the Plan tab, then check in each day."))
                } else if mine.isEmpty {
                    ContentUnavailableView {
                        Label("No check-ins yet", systemImage: "waveform.path.ecg")
                    } description: {
                        Text("Rate how you feel once a day. After a few days this becomes a chart you can show your prescriber.")
                    } actions: {
                        Button("Check In") { checkingIn = true }.buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        Section {
                            if todayCheckIn == nil {
                                Button { checkingIn = true } label: {
                                    Label("Check in for today", systemImage: "waveform.path.ecg").font(.headline)
                                }
                            } else {
                                Label("Checked in today", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                            }
                        }
                        if mine.count >= 2 {
                            Section {
                                SymptomChart(checkIns: mine.sorted { $0.day < $1.day }, symptoms: charted, stepStarts: TaperMath.stepStartDates(ordered))
                                    .frame(height: 230)
                                    .listRowInsets(EdgeInsets(top: 12, leading: 8, bottom: 8, trailing: 16))
                            } header: { Text("Over time") } footer: {
                                Text("Dashed lines mark the day each step started. Tap a symptom below to chart it.")
                            }
                        }
                        Section("Symptoms you have rated") {
                            ForEach(ranked, id: \.symptom) { row in
                                Button {
                                    if chosen.contains(row.symptom) { chosen.remove(row.symptom) } else { chosen.insert(row.symptom) }
                                } label: {
                                    HStack {
                                        Image(systemName: charted.contains(row.symptom) ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(charted.contains(row.symptom) ? Color.accentColor : Color.secondary)
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(row.symptom.name).foregroundStyle(.primary)
                                            Text("rated on \(row.days) day\(row.days == 1 ? "" : "s")").font(.caption).foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Text(String(format: "%.1f", row.average)).monospacedDigit()
                                            .foregroundStyle(Severity(rawValue: Int(row.average.rounded()))?.color ?? .secondary)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        Section("Check-ins") {
                            ForEach(mine) { checkIn in
                                Button { editing = checkIn } label: { CheckInRow(checkIn: checkIn) }.buttonStyle(.plain)
                            }
                            .onDelete { offsets in offsets.map { mine[$0] }.forEach(context.delete) }
                        }
                    }
                }
            }
            .navigationTitle("Symptoms")
            .toolbar {
                if plan != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { checkingIn = true } label: { Image(systemName: "plus") }.accessibilityLabel("New check-in")
                    }
                }
            }
            .sheet(isPresented: $checkingIn) { if let plan { CheckInEditorView(plan: plan, existing: todayCheckIn) } }
            .sheet(item: $editing) { c in if let plan { CheckInEditorView(plan: plan, existing: c) } }
        }
    }
}

struct CheckInRow: View {
    let checkIn: SymptomCheckIn

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Formatters.weekdayShort.string(from: checkIn.day)).font(.subheadline.weight(.semibold))
                Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer()
            if checkIn.overall > 0 {
                VStack(spacing: 1) {
                    Text("\(checkIn.overall)").font(.body.weight(.semibold)).monospacedDigit()
                    Text("of 10").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .contentShape(Rectangle())
    }

    private var detail: String {
        var parts: [String] = []
        let rated = checkIn.ratings.filter { $0.value > 0 }.sorted { $0.value > $1.value }
        if rated.isEmpty { parts.append("no symptoms rated") }
        else { parts.append(rated.prefix(3).map { "\($0.key.short) \($0.value)" }.joined(separator: " · ")) }
        if let hours = checkIn.sleepHours { parts.append("\(Formatters.amount(hours)) hr sleep") }
        if !checkIn.notes.isEmpty { parts.append(checkIn.notes) }
        return parts.joined(separator: " · ")
    }
}
