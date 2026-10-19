import SwiftUI
import UIKit

/// The report for the prescriber: the schedule as entered, how closely it was followed,
/// and how the person felt. It states plainly that the schedule came from the prescriber.
@MainActor
enum ReportExporter {
    static func export(plan: TaperPlan, steps: [TaperStep], logs: [DoseLog], checkIns: [SymptomCheckIn],
                       from start: Date, to end: Date, periodLabel: String) throws -> URL {
        let ordered = TaperMath.steps(steps, for: plan)
        let calendar = Calendar.current
        let periodLogs = logs.filter { $0.planID == plan.id && $0.day >= calendar.startOfDay(for: start) && $0.day <= end }.sorted { $0.day < $1.day }
        let periodCheckIns = TaperMath.checkIns(checkIns.filter { $0.planID == plan.id }, from: start, to: end)
        let adherence = TaperMath.adherence(logs: periodLogs, ordered: ordered, from: start, to: end)
        let progress = TaperMath.progress(ordered)
        let ranked = TaperMath.rankedSymptoms(periodCheckIns)

        var chart: UIImage?
        if periodCheckIns.count >= 2 {
            let renderer = ImageRenderer(content: SymptomChart(checkIns: periodCheckIns, symptoms: TaperMath.mostTracked(periodCheckIns), stepStarts: TaperMath.stepStartDates(ordered))
                .frame(width: 720, height: 250).padding(8).background(Color.white))
            renderer.scale = 2
            chart = renderer.uiImage
        }

        let footer = "\(AppConfig.appName) · schedule and entries typed in by the patient · not medical advice"
        return try PDFCanvas.render(footer: footer) { pdf in
            pdf.title("Taper record")
            pdf.subtitle("\(plan.medicationName) · \(periodLabel) · \(Formatters.date.string(from: start)) to \(Formatters.date.string(from: end)) · generated \(Formatters.dateTime.string(from: .now))")

            pdf.heading("Plan")
            var pairs: [(String, String)] = [
                ("Medicine", "\(plan.medicationName) (\(plan.form.name.lowercased()), \(plan.unit.rawValue))"),
                ("Schedule from", plan.prescriberName.isEmpty ? "the prescriber" : plan.prescriberName + (plan.clinicName.isEmpty ? "" : ", \(plan.clinicName)")),
                ("Started", Formatters.date.string(from: plan.startDate)),
            ]
            if let end = TaperMath.planEnd(ordered) { pairs.append(("Last scheduled day", Formatters.date.string(from: end))) }
            if progress.stepCount > 0, progress.stepNumber > 0 {
                pairs.append(("Currently on", "step \(progress.stepNumber) of \(progress.stepCount)"))
            }
            if !plan.reason.isEmpty { pairs.append(("Reason noted", plan.reason)) }
            pdf.keyValues(pairs)
            pdf.paragraph("This schedule was entered by the patient from the prescriber's instructions. The app does not calculate or adjust doses.", color: .darkGray)

            pdf.heading("Schedule as entered")
            pdf.table(headers: ["Step", "Doses", "Daily total", "From", "To", "Notes"],
                      widths: [0.08, 0.26, 0.13, 0.14, 0.14, 0.25],
                      rows: ordered.enumerated().map { index, step in
                          let r = TaperMath.range(of: step, in: ordered)
                          return ["\(index + 1)",
                                  step.doses.map { "\($0.label) \(Formatters.amount($0.amount))" }.joined(separator: ", "),
                                  Formatters.dose(step.dailyTotal, unit: plan.unit),
                                  Formatters.date.string(from: r.start),
                                  Formatters.date.string(from: r.end),
                                  step.notes]
                      })

            pdf.heading("Doses in this period")
            pdf.keyValues([
                ("Scheduled", "\(adherence.scheduled)"),
                ("Taken as scheduled", "\(adherence.taken) (\(Formatters.percent(adherence.fraction)))"),
                ("Partial", "\(adherence.partial)"),
                ("Skipped", "\(adherence.skipped)"),
                ("Not recorded", "\(adherence.notLogged)"),
            ])

            let notable = periodLogs.filter { $0.status != .taken || !$0.notes.isEmpty }
            if !notable.isEmpty {
                pdf.spacer(4)
                pdf.paragraph("Doses that were not taken as scheduled, or carried a note:", color: .darkGray)
                pdf.table(headers: ["Day", "Slot", "Planned", "Actual", "Status", "Note"],
                          widths: [0.16, 0.14, 0.12, 0.12, 0.14, 0.32],
                          rows: notable.map { log in
                              [Formatters.date.string(from: log.day), log.slotLabel,
                               Formatters.dose(log.plannedAmount, unit: plan.unit),
                               Formatters.dose(log.actualAmount, unit: plan.unit),
                               log.status.name, log.notes]
                          })
            }

            pdf.heading("How the patient felt")
            if periodCheckIns.isEmpty {
                pdf.paragraph("No check-ins in this period.", color: .darkGray)
            } else {
                pdf.keyValues([
                    ("Check-ins", "\(periodCheckIns.count)"),
                    ("Average severity", TaperMath.averageSeverity(periodCheckIns).map { String(format: "%.1f of 4", $0) } ?? "—"),
                ])
                if let chart {
                    pdf.spacer(4)
                    pdf.image(chart, caption: "The symptoms rated most often over the period. Dashed lines mark the start of each step.", maxHeight: 180)
                }
                pdf.table(headers: ["Symptom", "Average", "Days rated", "Worst"], widths: [0.4, 0.2, 0.2, 0.2],
                          rows: ranked.map { row in
                              let worst = periodCheckIns.map { $0.rating(row.symptom) }.max() ?? 0
                              return [row.symptom.name, String(format: "%.1f", row.average), "\(row.days)", "\(worst) of 4"]
                          })
                let noted = periodCheckIns.filter { !$0.notes.isEmpty }
                if !noted.isEmpty {
                    pdf.spacer(4)
                    pdf.table(headers: ["Day", "Overall", "Sleep", "Note"], widths: [0.16, 0.12, 0.12, 0.60],
                              rows: noted.map { c in
                                  [Formatters.date.string(from: c.day),
                                   c.overall == 0 ? "" : "\(c.overall)/10",
                                   c.sleepHours.map { "\(Formatters.amount($0)) hr" } ?? "",
                                   c.notes]
                              })
                }
            }

            if !plan.notes.isEmpty {
                pdf.heading("Patient notes")
                pdf.paragraph(plan.notes)
            }

            pdf.spacer(10)
            pdf.paragraph(AppConfig.disclaimer, color: .darkGray)
        }
    }
}
