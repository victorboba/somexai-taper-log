import SwiftUI
import SwiftData

struct ReportView: View {
    @Query(sort: \TaperPlan.createdAt) private var plans: [TaperPlan]
    @Query(sort: \TaperStep.startDate) private var allSteps: [TaperStep]
    @Query(sort: \DoseLog.day, order: .reverse) private var logs: [DoseLog]
    @Query(sort: \SymptomCheckIn.day, order: .reverse) private var checkIns: [SymptomCheckIn]

    @State private var period: Period = .days30
    @State private var exportFile: ExportFile?
    @State private var exportError: String?

    enum Period: String, CaseIterable, Identifiable {
        case days14 = "14 days", days30 = "30 days", days90 = "90 days", all = "All"
        var id: String { rawValue }
        var days: Int? {
            switch self {
            case .days14: return 14
            case .days30: return 30
            case .days90: return 90
            case .all: return nil
            }
        }
    }

    private var plan: TaperPlan? { plans.first { $0.isActive } ?? plans.first }
    private var ordered: [TaperStep] { TaperMath.steps(allSteps, for: plan) }
    private var start: Date {
        let today = Calendar.current.startOfDay(for: .now)
        guard let days = period.days else { return plan.map { Calendar.current.startOfDay(for: $0.startDate) } ?? today }
        return Calendar.current.date(byAdding: .day, value: -(days - 1), to: today) ?? today
    }
    private var mineLogs: [DoseLog] { logs.filter { $0.planID == plan?.id && $0.day >= start } }
    private var mineCheckIns: [SymptomCheckIn] { TaperMath.checkIns(checkIns.filter { $0.planID == plan?.id }, from: start, to: .now) }
    private var adherence: TaperMath.Adherence { TaperMath.adherence(logs: mineLogs, ordered: ordered, from: start, to: .now) }

    var body: some View {
        NavigationStack {
            Group {
                if let plan {
                    List {
                        Section {
                            Picker("Period", selection: $period) { ForEach(Period.allCases) { Text($0.rawValue).tag($0) } }
                                .pickerStyle(.segmented).listRowBackground(Color.clear).listRowInsets(EdgeInsets())
                        }
                        Section("Doses") {
                            LabeledContent("Scheduled", value: "\(adherence.scheduled)")
                            LabeledContent("Taken as scheduled", value: "\(adherence.taken) · \(Formatters.percent(adherence.fraction))")
                            if adherence.partial > 0 { LabeledContent("Partial", value: "\(adherence.partial)").foregroundStyle(.orange) }
                            if adherence.skipped > 0 { LabeledContent("Skipped", value: "\(adherence.skipped)").foregroundStyle(.red) }
                            if adherence.notLogged > 0 { LabeledContent("Not recorded", value: "\(adherence.notLogged)").foregroundStyle(.secondary) }
                        }
                        if !ordered.isEmpty {
                            Section {
                                DoseChart(plan: plan, ordered: ordered, logs: mineLogs, start: start, end: .now)
                                    .frame(height: 190)
                                    .listRowInsets(EdgeInsets(top: 12, leading: 8, bottom: 8, trailing: 16))
                            } header: { Text("Dose over time") } footer: {
                                Text("The dashed line is your schedule. Dots are what you recorded taking.")
                            }
                        }
                        Section("How you felt") {
                            LabeledContent("Check-ins", value: "\(mineCheckIns.count)")
                            if let average = TaperMath.averageSeverity(mineCheckIns) {
                                LabeledContent("Average severity", value: String(format: "%.1f of 4", average))
                            }
                            ForEach(TaperMath.rankedSymptoms(mineCheckIns).prefix(3), id: \.symptom) { row in
                                LabeledContent(row.symptom.name, value: String(format: "%.1f", row.average))
                            }
                        }
                        Section {
                            Button {
                                export { try ReportExporter.export(plan: plan, steps: allSteps, logs: logs, checkIns: checkIns, from: start, to: .now, periodLabel: period.rawValue) }
                            } label: { Label("PDF for your prescriber", systemImage: "doc.richtext") }
                            Button { export { try CSVExporter.write(CSVExporter.dosesCSV(mineLogs, plan: plan, ordered: ordered), suffix: "doses") } } label: {
                                Label("Doses CSV", systemImage: "tablecells")
                            }
                            Button { export { try CSVExporter.write(CSVExporter.symptomsCSV(mineCheckIns), suffix: "symptoms") } } label: {
                                Label("Symptoms CSV", systemImage: "tablecells")
                            }
                        } header: { Text("Export") } footer: {
                            Text("The PDF says plainly that the schedule came from your prescriber and that you typed it in.")
                        }
                        Section { Text(AppConfig.disclaimer).font(.footnote).foregroundStyle(.secondary) }
                    }
                } else {
                    ContentUnavailableView("No plan yet", systemImage: "doc.text", description: Text("Set the plan up on the Plan tab to build a report."))
                }
            }
            .navigationTitle("Report")
            .sheet(item: $exportFile) { ShareSheet(url: $0.url) }
            .alert("Export failed", isPresented: Binding(get: { exportError != nil }, set: { if !$0 { exportError = nil } })) {
                Button("OK") { exportError = nil }
            } message: { Text(exportError ?? "") }
        }
    }

    private func export(_ make: () throws -> URL) {
        do { exportFile = ExportFile(url: try make()) } catch { exportError = error.localizedDescription }
    }
}
