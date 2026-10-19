import Foundation
import SwiftData

#if DEBUG
/// Debug-only sample data: a fictional nine-step clonazepam taper, ten weeks in, with doses ticked off
/// and daily check-ins whose symptoms rise for a few days after each reduction.
@MainActor
enum SampleData {
    static func insert(into context: ModelContext) {
        let hasPlan = !((try? context.fetch(FetchDescriptor<TaperPlan>()))?.isEmpty ?? true)
        guard !hasPlan else { return }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let planStart = calendar.date(byAdding: .day, value: -78, to: today) ?? today

        let plan = TaperPlan(medicationName: "Clonazepam", unit: .mg, form: .tablet)
        plan.prescriberName = "Dr. Nakamura"
        plan.clinicName = "Elmwood Family Practice"
        plan.startDate = planStart
        plan.reason = "Planned reduction after long-term use"
        context.insert(plan)

        // The schedule as a prescriber might write it: a slow step down over months.
        let schedule: [(morning: Double, evening: Double, days: Int)] = [
            (1.0, 1.0, 14), (1.0, 0.75, 14), (0.75, 0.75, 14), (0.75, 0.5, 14),
            (0.5, 0.5, 14), (0.5, 0.25, 21), (0.25, 0.25, 21), (0.25, 0.125, 21), (0.125, 0, 28),
        ]
        var stepStart = planStart
        var steps: [TaperStep] = []
        for (index, row) in schedule.enumerated() {
            var doses = [DoseSlot(label: "Morning", amount: row.morning)]
            if row.evening > 0 { doses.append(DoseSlot(label: "Evening", amount: row.evening)) }
            let step = TaperStep(planID: plan.id, orderIndex: index, startDate: stepStart, durationDays: row.days, doses: doses)
            if index == 5 { step.notes = "Hold here longer if the first week is rough." }
            context.insert(step)
            steps.append(step)
            stepStart = calendar.date(byAdding: .day, value: row.days, to: stepStart) ?? stepStart
        }

        // Ten weeks of ticked-off doses, with the odd late or skipped one.
        var day = planStart
        var index = 0
        while day <= today {
            let slots = TaperMath.scheduledDoses(on: day, in: steps, calendar: calendar)
            let step = TaperMath.step(on: day, in: steps, calendar: calendar)
            for slot in slots {
                index += 1
                // Almost always taken; occasionally partial, rarely skipped, sometimes not recorded at all.
                let roll = index % 23
                if roll == 7 { continue }
                let status: DoseStatus = roll == 3 ? .partial : (roll == 17 ? .skipped : .taken)
                let log = DoseLog(plan: plan, step: step, day: day, slot: slot, status: status)
                if status == .partial {
                    log.actualAmount = slot.amount / 2
                    log.notes = "Took half, felt too drowsy in the morning."
                }
                if status == .skipped { log.notes = "Forgot until the next day." }
                let hour = slot.label == "Morning" ? 8 : 20
                log.takenAt = status == .skipped ? nil : calendar.date(bySettingHour: hour, minute: (index * 7) % 55, second: 0, of: day)
                context.insert(log)
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }

        // Check-ins: symptoms lift for a few days after each reduction, then settle.
        let stepStarts = TaperMath.stepStartDates(steps, calendar: calendar)
        day = planStart
        var dayIndex = 0
        while day <= today {
            dayIndex += 1
            if dayIndex % 3 == 0, day != today { day = calendar.date(byAdding: .day, value: 1, to: day) ?? day; continue }
            let daysSinceChange = stepStarts.filter { $0 <= day }.last.map { calendar.dateComponents([.day], from: $0, to: day).day ?? 99 } ?? 99
            let flare = max(0, 3 - daysSinceChange / 2)
            // A day's worth of wobble so the series reads like real answers, not a formula.
            let wobble = (calendar.component(.day, from: day) % 3) - 1
            let check = SymptomCheckIn(plan: plan, day: day)
            var ratings: [Symptom: Int] = [
                .sleep: max(1, min(4, 1 + flare + wobble)),
                .anxiety: max(1, min(4, 1 + flare + (wobble == 1 ? 1 : 0))),
                .irritability: max(1, min(4, flare + 1)),
            ]
            if flare >= 2 { ratings[.headache] = 2 + max(0, wobble); ratings[.dizziness] = 1 }
            if daysSinceChange <= 1 { ratings[.nausea] = 2 }
            check.ratings = ratings
            check.overall = max(2, 8 - flare * 2)
            check.sleepHours = 7.5 - Double(flare) * 0.8
            if daysSinceChange == 0 { check.notes = "First day on the new dose." }
            if flare >= 3 { check.notes = "Rough night, woke at 3am." }
            context.insert(check)
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        try? context.save()
    }
}
#endif
