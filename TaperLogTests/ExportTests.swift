import XCTest
import SwiftData
import PDFKit
@testable import TaperLog

@MainActor
final class ExportTests: XCTestCase {
    private var container: ModelContainer!
    private let cal = Calendar(identifier: .gregorian)

    override func setUpWithError() throws {
        container = try ModelContainer(for: TaperPlan.self, TaperStep.self, DoseLog.self, SymptomCheckIn.self,
                                       configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    private func day(_ offset: Int) -> Date {
        cal.date(byAdding: .day, value: offset, to: cal.date(from: DateComponents(year: 2026, month: 9, day: 1))!)!
    }

    private func sample() -> (TaperPlan, [TaperStep], [DoseLog], [SymptomCheckIn]) {
        let plan = TaperPlan(medicationName: "Clonazepam", unit: .mg)
        plan.prescriberName = "Dr. Nakamura"
        plan.startDate = day(0)
        container.mainContext.insert(plan)
        let steps = [
            TaperStep(planID: plan.id, orderIndex: 0, startDate: day(0), durationDays: 7,
                      doses: [DoseSlot(label: "Morning", amount: 1), DoseSlot(label: "Evening", amount: 1)]),
            TaperStep(planID: plan.id, orderIndex: 1, startDate: day(7), durationDays: 7,
                      doses: [DoseSlot(label: "Morning", amount: 1), DoseSlot(label: "Evening", amount: 0.5)]),
        ]
        steps.forEach { container.mainContext.insert($0) }
        var logs: [DoseLog] = []
        for offset in 0..<3 {
            for (index, slot) in steps[0].doses.enumerated() {
                let status: DoseStatus = (offset == 1 && index == 1) ? .skipped : .taken
                let log = DoseLog(plan: plan, step: steps[0], day: day(offset), slot: slot, status: status)
                if status == .skipped { log.notes = "Fell asleep early, \"missed\" it" }
                container.mainContext.insert(log)
                logs.append(log)
            }
        }
        var checkIns: [SymptomCheckIn] = []
        for offset in 0..<4 {
            let c = SymptomCheckIn(plan: plan, day: day(offset))
            c.ratings = [.sleep: 2 + offset % 2, .anxiety: 2]
            c.overall = 6
            c.sleepHours = 6.5
            if offset == 2 { c.notes = "Headache most of the afternoon." }
            container.mainContext.insert(c)
            checkIns.append(c)
        }
        return (plan, steps, logs, checkIns)
    }

    func testDoseCSVHasHeaderAndOneRowPerLog() {
        let (plan, steps, logs, _) = sample()
        let lines = CSVExporter.dosesCSV(logs, plan: plan, ordered: steps).split(separator: "\n")
        XCTAssertEqual(lines.count, 7)
        XCTAssertEqual(lines[0], "day,step,slot,planned,actual,unit,status,taken_at,notes")
        XCTAssertTrue(lines.contains { $0.contains("\"Morning\",\"1\",\"1\",\"mg\",\"taken\"") })
        XCTAssertTrue(lines.contains { $0.contains("\"skipped\"") && $0.contains("\"Fell asleep early, \"\"missed\"\" it\"") })
    }

    func testSymptomCSVHasEverySymptomColumn() {
        let (_, _, _, checkIns) = sample()
        let csv = CSVExporter.symptomsCSV(checkIns)
        let lines = csv.split(separator: "\n")
        XCTAssertEqual(lines.count, 5)
        XCTAssertTrue(lines[0].contains("sleep"))
        XCTAssertTrue(lines[0].contains("brainFog"))
        XCTAssertTrue(lines[1].contains("\"6\""), "the overall score is written out")
        XCTAssertTrue(lines.contains { $0.contains("Headache most of the afternoon.") })
    }

    func testPDFStatesTheScheduleCameFromThePrescriber() throws {
        let (plan, steps, logs, checkIns) = sample()
        let url = try ReportExporter.export(plan: plan, steps: steps, logs: logs, checkIns: checkIns,
                                            from: day(0), to: day(6), periodLabel: "7 days")
        let document = try XCTUnwrap(PDFDocument(url: url))
        // PDF text wraps at the column width, so collapse whitespace before matching a phrase.
        let text = (0..<document.pageCount).compactMap { document.page(at: $0)?.string }.joined()
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        XCTAssertTrue(text.contains("Taper record"))
        XCTAssertTrue(text.contains("Clonazepam"))
        XCTAssertTrue(text.contains("Dr. Nakamura"))
        XCTAssertTrue(text.contains("Schedule as entered"))
        XCTAssertTrue(text.contains("entered by the patient"), "the report must say who typed the schedule in")
        XCTAssertTrue(text.contains("does not calculate"))
        XCTAssertTrue(text.contains("not medical advice"))
    }

    func testPDFSurvivesAPlanWithNoDataYet() throws {
        let plan = TaperPlan(medicationName: "Prednisone", unit: .mg)
        container.mainContext.insert(plan)
        let url = try ReportExporter.export(plan: plan, steps: [], logs: [], checkIns: [], from: day(0), to: day(6), periodLabel: "7 days")
        let document = try XCTUnwrap(PDFDocument(url: url))
        let text = try XCTUnwrap(document.page(at: 0)?.string)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        XCTAssertTrue(text.contains("Prednisone"))
        XCTAssertTrue(text.contains("No check-ins in this period."))
    }
}
