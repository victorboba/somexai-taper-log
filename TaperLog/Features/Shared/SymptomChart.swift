import SwiftUI
import Charts

/// Symptom severity over time with a dashed line at each step change, so a rough patch
/// can be read next to the reduction that may explain it.
struct SymptomChart: View {
    let checkIns: [SymptomCheckIn]
    let symptoms: [Symptom]
    var stepStarts: [Date] = []

    private var rows: [(day: Date, symptom: String, value: Double)] {
        symptoms.flatMap { symptom in
            TaperMath.series(checkIns, symptom: symptom).map { ($0.day, symptom.short, $0.value) }
        }
    }

    private var visibleStepStarts: [Date] {
        guard let first = checkIns.first?.day, let last = checkIns.last?.day else { return [] }
        return stepStarts.filter { $0 >= first && $0 <= last }
    }

    var body: some View {
        Chart {
            ForEach(Array(visibleStepStarts.enumerated()), id: \.offset) { _, date in
                RuleMark(x: .value("Step change", date))
                    .foregroundStyle(Color.secondary.opacity(0.45))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
            }
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                LineMark(x: .value("Day", row.day), y: .value("Severity", row.value))
                    .foregroundStyle(by: .value("Symptom", row.symptom))
                    .interpolationMethod(.monotone)
                PointMark(x: .value("Day", row.day), y: .value("Severity", row.value))
                    .foregroundStyle(by: .value("Symptom", row.symptom))
                    .symbolSize(28)
            }
        }
        .chartYScale(domain: 0...4)
        .chartYAxis {
            AxisMarks(values: [0, 1, 2, 3, 4]) { value in
                AxisGridLine()
                AxisValueLabel { if let v = value.as(Int.self) { Text("\(v)") } }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
            }
        }
        .chartLegend(position: .top, alignment: .leading)
    }
}

/// Daily total actually taken against the schedule, so the step-down is visible as a staircase.
struct DoseChart: View {
    let plan: TaperPlan
    let ordered: [TaperStep]
    let logs: [DoseLog]
    let start: Date
    let end: Date

    private var rows: [(day: Date, scheduled: Double, taken: Double)] {
        let calendar = Calendar.current
        var result: [(Date, Double, Double)] = []
        var day = calendar.startOfDay(for: start)
        let last = calendar.startOfDay(for: end)
        while day <= last {
            let step = TaperMath.step(on: day, in: ordered)
            if let step {
                result.append((day, step.dailyTotal, TaperMath.takenTotal(logs, on: day)))
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return result
    }

    var body: some View {
        Chart {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                LineMark(x: .value("Day", row.day), y: .value("Scheduled", row.scheduled), series: .value("Series", "Scheduled"))
                    .foregroundStyle(Color.secondary)
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 3]))
                    .interpolationMethod(.stepEnd)
                PointMark(x: .value("Day", row.day), y: .value("Taken", row.taken))
                    .foregroundStyle(row.taken >= row.scheduled ? Color.accentColor : Color.orange)
                    .symbolSize(24)
            }
        }
        .chartYAxisLabel(plan.unit.rawValue)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
            }
        }
    }
}
