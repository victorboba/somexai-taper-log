import Foundation
import WidgetKit

enum WidgetSync {
    static func update(plan: TaperPlan?, steps: [TaperStep], logs: [DoseLog], checkIns: [SymptomCheckIn], now: Date = .now) {
        var snapshot = WidgetSnapshot()
        if let plan, plan.isActive {
            let ordered = TaperMath.steps(steps, for: plan)
            let progress = TaperMath.progress(ordered, now: now)
            snapshot.hasPlan = true
            snapshot.medicationName = plan.medicationName
            snapshot.stepNumber = progress.stepNumber
            snapshot.stepCount = progress.stepCount
            if let current = progress.current {
                snapshot.stepLabel = current.doseSummary(unit: plan.unit)
                snapshot.dailyTotal = Formatters.dose(current.dailyTotal, unit: plan.unit)
            }
            let slots = TaperMath.scheduledDoses(on: now, in: ordered)
            snapshot.dosesDueToday = slots.count
            let today = TaperMath.logs(logs, on: now)
            snapshot.dosesTakenToday = slots.filter { slot in today.contains { $0.slotLabel == slot.label && $0.status != .skipped } }.count
            snapshot.nextStepDate = progress.nextStepDate
            snapshot.checkedInToday = checkIns.contains { Calendar.current.isDate($0.day, inSameDayAs: now) && $0.hasContent }
        }
        snapshot.save()
        WidgetCenter.shared.reloadAllTimelines()
    }
}
