import XCTest
import SwiftData
@testable import TaperLog

@MainActor
final class TaperMathTests: XCTestCase {
    private var container: ModelContainer!
    private var plan: TaperPlan!
    private let cal = Calendar(identifier: .gregorian)

    override func setUpWithError() throws {
        container = try ModelContainer(for: TaperPlan.self, TaperStep.self, DoseLog.self, SymptomCheckIn.self,
                                       configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        plan = TaperPlan(medicationName: "Clonazepam", unit: .mg)
        plan.startDate = day(0)
        container.mainContext.insert(plan)
    }

    /// Day 0 is 2026-09-01.
    private func day(_ offset: Int) -> Date {
        cal.date(byAdding: .day, value: offset, to: cal.date(from: DateComponents(year: 2026, month: 9, day: 1))!)!
    }

    @discardableResult
    private func step(_ index: Int, start: Int, days: Int, doses: [DoseSlot]) -> TaperStep {
        let s = TaperStep(planID: plan.id, orderIndex: index, startDate: day(start), durationDays: days, doses: doses)
        container.mainContext.insert(s)
        return s
    }

    private func threeStepPlan() -> [TaperStep] {
        [step(0, start: 0, days: 14, doses: [DoseSlot(label: "Morning", amount: 1), DoseSlot(label: "Evening", amount: 1)]),
         step(1, start: 14, days: 14, doses: [DoseSlot(label: "Morning", amount: 1), DoseSlot(label: "Evening", amount: 0.5)]),
         step(2, start: 28, days: 21, doses: [DoseSlot(label: "Morning", amount: 0.5)])]
    }

    // MARK: Slots

    func testDoseSlotsSurviveEncoding() {
        let slots = [DoseSlot(label: "Morning", amount: 0.125), DoseSlot(label: "Evening", amount: 1)]
        let decoded = DoseSlot.decode(DoseSlot.encode(slots))
        XCTAssertEqual(decoded, slots)
        XCTAssertEqual(DoseSlot.decode(""), [])
        // Separators typed into a label must not corrupt the row.
        let awkward = DoseSlot.decode(DoseSlot.encode([DoseSlot(label: "Before|bed:", amount: 2)]))
        XCTAssertEqual(awkward.count, 1)
        XCTAssertEqual(awkward.first?.amount, 2)
    }

    func testDailyTotalAndSummary() {
        let s = step(0, start: 0, days: 7, doses: [DoseSlot(label: "Morning", amount: 0.5), DoseSlot(label: "Evening", amount: 0.25)])
        XCTAssertEqual(s.dailyTotal, 0.75, accuracy: 0.0001)
        XCTAssertEqual(s.doseSummary(unit: .mg), "0.5 mg + 0.25 mg")
    }

    // MARK: Dates

    func testStepRangeEndsWhereTheNextBegins() {
        let steps = threeStepPlan()
        let first = TaperMath.range(of: steps[0], in: steps, calendar: cal)
        XCTAssertEqual(first.start, day(0))
        XCTAssertEqual(first.end, day(13), "a step runs until the day before the next one starts")
        let last = TaperMath.range(of: steps[2], in: steps, calendar: cal)
        XCTAssertEqual(last.end, day(48), "the final step uses its own duration")
        XCTAssertEqual(TaperMath.planEnd(steps, calendar: cal), day(48))
    }

    func testStepOnDayPicksTheRightRung() {
        let steps = threeStepPlan()
        XCTAssertEqual(TaperMath.step(on: day(0), in: steps, calendar: cal)?.id, steps[0].id)
        XCTAssertEqual(TaperMath.step(on: day(13), in: steps, calendar: cal)?.id, steps[0].id)
        XCTAssertEqual(TaperMath.step(on: day(14), in: steps, calendar: cal)?.id, steps[1].id)
        XCTAssertEqual(TaperMath.step(on: day(48), in: steps, calendar: cal)?.id, steps[2].id)
        XCTAssertNil(TaperMath.step(on: day(49), in: steps, calendar: cal), "after the last day nothing is scheduled")
        XCTAssertNil(TaperMath.step(on: day(-1), in: steps, calendar: cal), "nothing is scheduled before the plan starts")
    }

    func testScheduledDosesFollowTheStep() {
        let steps = threeStepPlan()
        XCTAssertEqual(TaperMath.scheduledDoses(on: day(20), in: steps, calendar: cal).map(\.amount), [1, 0.5])
        XCTAssertEqual(TaperMath.scheduledDoses(on: day(30), in: steps, calendar: cal).count, 1)
        XCTAssertTrue(TaperMath.scheduledDoses(on: day(100), in: steps, calendar: cal).isEmpty)
    }

    // MARK: Progress

    func testProgressReportsStepAndCountdown() {
        let steps = threeStepPlan()
        let p = TaperMath.progress(steps, now: day(17), calendar: cal)
        XCTAssertEqual(p.stepNumber, 2)
        XCTAssertEqual(p.stepCount, 3)
        XCTAssertEqual(p.dayInStep, 4)
        XCTAssertEqual(p.daysInStep, 14)
        XCTAssertEqual(p.daysToNextStep, 11)
        XCTAssertEqual(p.nextStepDate, day(28))
        XCTAssertFalse(p.hasFinished)
        XCTAssertEqual(p.stepFraction, 4.0 / 14.0, accuracy: 0.001)
    }

    func testProgressAfterTheLastDay() {
        let steps = threeStepPlan()
        let p = TaperMath.progress(steps, now: day(60), calendar: cal)
        XCTAssertTrue(p.hasFinished)
        XCTAssertNil(p.current)
        XCTAssertEqual(p.planEnd, day(48))
    }

    func testProgressWithNoSteps() {
        let p = TaperMath.progress([], now: day(3), calendar: cal)
        XCTAssertEqual(p.stepCount, 0)
        XCTAssertNil(p.current)
        XCTAssertFalse(p.hasStarted)
    }

    // MARK: Adherence

    func testAdherenceCountsEveryOutcome() {
        let steps = threeStepPlan()
        // Days 0 and 1 have two doses each. Take three, skip one, leave one unrecorded, one partial.
        let slots = steps[0].doses
        func log(_ offset: Int, _ slot: DoseSlot, _ status: DoseStatus) {
            container.mainContext.insert(DoseLog(plan: plan, step: steps[0], day: day(offset), slot: slot, status: status))
        }
        log(0, slots[0], .taken)
        log(0, slots[1], .taken)
        log(1, slots[0], .partial)
        log(1, slots[1], .skipped)
        let all = try! container.mainContext.fetch(FetchDescriptor<DoseLog>())
        let a = TaperMath.adherence(logs: all, ordered: steps, from: day(0), to: day(2), calendar: cal)
        XCTAssertEqual(a.scheduled, 6, "three days at two doses each")
        XCTAssertEqual(a.taken, 2)
        XCTAssertEqual(a.partial, 1)
        XCTAssertEqual(a.skipped, 1)
        XCTAssertEqual(a.notLogged, 2)
        XCTAssertEqual(a.logged, 4)
        XCTAssertEqual(a.fraction, 2.0 / 6.0, accuracy: 0.001)
    }

    func testAdherenceIgnoresDaysOutsideThePlan() {
        let steps = threeStepPlan()
        let a = TaperMath.adherence(logs: [], ordered: steps, from: day(45), to: day(55), calendar: cal)
        XCTAssertEqual(a.scheduled, 4, "only days 45 to 48 are still scheduled")
    }

    func testTakenTotalAddsUpTheDay() {
        let steps = threeStepPlan()
        let slots = steps[0].doses
        let a = DoseLog(plan: plan, step: steps[0], day: day(0), slot: slots[0], status: .taken)
        let b = DoseLog(plan: plan, step: steps[0], day: day(0), slot: slots[1], status: .partial)
        b.actualAmount = 0.5
        [a, b].forEach { container.mainContext.insert($0) }
        let all = try! container.mainContext.fetch(FetchDescriptor<DoseLog>())
        XCTAssertEqual(TaperMath.takenTotal(all, on: day(0), calendar: cal), 1.5, accuracy: 0.0001)
    }

    // MARK: Symptoms

    func testCheckInRatingsRoundTripAndDropZeroes() {
        let c = SymptomCheckIn(plan: plan, day: day(2))
        c.ratings = [.sleep: 3, .anxiety: 2, .nausea: 0]
        XCTAssertEqual(c.rating(.sleep), 3)
        XCTAssertEqual(c.rating(.nausea), 0)
        XCTAssertFalse(c.ratingsRaw.contains("nausea"), "a zero rating is not stored")
        XCTAssertEqual(c.severityAverage, 2.5, accuracy: 0.001)
        XCTAssertEqual(c.worst?.symptom, .sleep)
        XCTAssertTrue(c.hasContent)
        XCTAssertFalse(SymptomCheckIn(plan: plan, day: day(3)).hasContent)
    }

    func testRankedSymptomsAndSeries() {
        for (offset, sleep) in [(0, 4), (1, 2), (2, 3)] {
            let c = SymptomCheckIn(plan: plan, day: day(offset))
            c.ratings = [.sleep: sleep, .anxiety: 1]
            container.mainContext.insert(c)
        }
        let all = try! container.mainContext.fetch(FetchDescriptor<SymptomCheckIn>())
        let ranked = TaperMath.rankedSymptoms(all)
        XCTAssertEqual(ranked.first?.symptom, .sleep)
        XCTAssertEqual(ranked.first?.average ?? 0, 3, accuracy: 0.001)
        XCTAssertEqual(ranked.first?.days, 3)
        XCTAssertEqual(TaperMath.series(all, symptom: .sleep).map(\.value), [4, 2, 3])
        XCTAssertEqual(TaperMath.averageSeverity(all) ?? 0, 2.0, accuracy: 0.001)
    }

    func testSeverityAroundAStepChange() {
        // Calm before the change, worse after.
        for offset in 7...13 {
            let c = SymptomCheckIn(plan: plan, day: day(offset))
            c.ratings = [.anxiety: 1]
            container.mainContext.insert(c)
        }
        for offset in 14...18 {
            let c = SymptomCheckIn(plan: plan, day: day(offset))
            c.ratings = [.anxiety: 3]
            container.mainContext.insert(c)
        }
        let all = try! container.mainContext.fetch(FetchDescriptor<SymptomCheckIn>())
        let around = TaperMath.severityAround(stepStart: day(14), checkIns: all, calendar: cal)
        XCTAssertEqual(around.before ?? 0, 1, accuracy: 0.001)
        XCTAssertEqual(around.after ?? 0, 3, accuracy: 0.001)
    }

    func testFormatters() {
        XCTAssertEqual(Formatters.amount(1), "1")
        XCTAssertEqual(Formatters.amount(0.5), "0.5")
        XCTAssertEqual(Formatters.amount(0.125), "0.125")
        XCTAssertEqual(Formatters.dose(0.25, unit: .mg), "0.25 mg")
        XCTAssertEqual(Formatters.percent(0.826), "83%")
        XCTAssertEqual(Formatters.days(0), "today")
        XCTAssertEqual(Formatters.days(1), "1 day")
        XCTAssertEqual(Formatters.days(9), "9 days")
    }
}
