import Foundation

/// Dates, adherence and symptom series over the plan the user entered.
/// Nothing here proposes a dose or a schedule; it only reads what was typed in.
enum TaperMath {
    // MARK: Steps and dates

    static func steps(_ all: [TaperStep], for plan: TaperPlan?) -> [TaperStep] {
        guard let plan else { return [] }
        return all.filter { $0.planID == plan.id }.sorted { ($0.startDate, $0.orderIndex) < ($1.startDate, $1.orderIndex) }
    }

    /// First and last day of a step. The next step's start ends it; the final step uses its own duration.
    static func range(of step: TaperStep, in ordered: [TaperStep], calendar: Calendar = .current) -> (start: Date, end: Date) {
        let start = calendar.startOfDay(for: step.startDate)
        if let index = ordered.firstIndex(where: { $0.id == step.id }), index + 1 < ordered.count {
            let nextStart = calendar.startOfDay(for: ordered[index + 1].startDate)
            let end = calendar.date(byAdding: .day, value: -1, to: nextStart) ?? start
            return (start, max(start, end))
        }
        let end = calendar.date(byAdding: .day, value: max(step.durationDays, 1) - 1, to: start) ?? start
        return (start, end)
    }

    static func step(on date: Date, in ordered: [TaperStep], calendar: Calendar = .current) -> TaperStep? {
        let day = calendar.startOfDay(for: date)
        return ordered.last { step in
            let r = range(of: step, in: ordered, calendar: calendar)
            return day >= r.start && day <= r.end
        }
    }

    /// The doses due on a day, or none when the day falls outside the plan.
    static func scheduledDoses(on date: Date, in ordered: [TaperStep], calendar: Calendar = .current) -> [DoseSlot] {
        step(on: date, in: ordered, calendar: calendar)?.doses ?? []
    }

    static func planEnd(_ ordered: [TaperStep], calendar: Calendar = .current) -> Date? {
        guard let last = ordered.last else { return nil }
        return range(of: last, in: ordered, calendar: calendar).end
    }

    /// The day each step begins, for marking a chart.
    static func stepStartDates(_ ordered: [TaperStep], calendar: Calendar = .current) -> [Date] {
        ordered.map { calendar.startOfDay(for: $0.startDate) }
    }

    // MARK: Progress

    struct Progress {
        var stepNumber = 0
        var stepCount = 0
        var current: TaperStep?
        var dayInStep = 0
        var daysInStep = 0
        var daysToNextStep: Int?
        var nextStep: TaperStep?
        var nextStepDate: Date?
        var planEnd: Date?
        var daysToEnd: Int?
        var hasStarted = false
        var hasFinished = false

        var stepFraction: Double { daysInStep > 0 ? min(Double(dayInStep) / Double(daysInStep), 1) : 0 }
    }

    static func progress(_ ordered: [TaperStep], now: Date = .now, calendar: Calendar = .current) -> Progress {
        var p = Progress()
        p.stepCount = ordered.count
        p.planEnd = planEnd(ordered, calendar: calendar)
        guard !ordered.isEmpty else { return p }
        let today = calendar.startOfDay(for: now)
        p.hasStarted = today >= calendar.startOfDay(for: ordered[0].startDate)
        if let end = p.planEnd {
            p.hasFinished = today > end
            p.daysToEnd = calendar.dateComponents([.day], from: today, to: end).day
        }
        guard let current = step(on: today, in: ordered, calendar: calendar),
              let index = ordered.firstIndex(where: { $0.id == current.id }) else { return p }
        p.current = current
        p.stepNumber = index + 1
        let r = range(of: current, in: ordered, calendar: calendar)
        p.daysInStep = (calendar.dateComponents([.day], from: r.start, to: r.end).day ?? 0) + 1
        p.dayInStep = (calendar.dateComponents([.day], from: r.start, to: today).day ?? 0) + 1
        if index + 1 < ordered.count {
            let next = ordered[index + 1]
            p.nextStep = next
            let nextStart = calendar.startOfDay(for: next.startDate)
            p.nextStepDate = nextStart
            p.daysToNextStep = calendar.dateComponents([.day], from: today, to: nextStart).day
        }
        return p
    }

    // MARK: Adherence

    struct Adherence: Equatable {
        var scheduled = 0
        var taken = 0
        var partial = 0
        var skipped = 0
        var notLogged = 0
        /// Doses marked taken as a share of doses scheduled.
        var fraction: Double { scheduled > 0 ? Double(taken) / Double(scheduled) : 0 }
        var logged: Int { taken + partial + skipped }
    }

    static func adherence(logs: [DoseLog], ordered: [TaperStep], from start: Date, to end: Date, calendar: Calendar = .current) -> Adherence {
        var a = Adherence()
        guard !ordered.isEmpty else { return a }
        var day = calendar.startOfDay(for: start)
        let last = calendar.startOfDay(for: end)
        let byDay = Dictionary(grouping: logs) { calendar.startOfDay(for: $0.day) }
        while day <= last {
            let slots = scheduledDoses(on: day, in: ordered, calendar: calendar)
            let dayLogs = byDay[day] ?? []
            a.scheduled += slots.count
            for slot in slots {
                guard let log = dayLogs.first(where: { $0.slotLabel == slot.label }) else { a.notLogged += 1; continue }
                switch log.status {
                case .taken: a.taken += 1
                case .partial: a.partial += 1
                case .skipped: a.skipped += 1
                }
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return a
    }

    static func logs(_ all: [DoseLog], on day: Date, calendar: Calendar = .current) -> [DoseLog] {
        let target = calendar.startOfDay(for: day)
        return all.filter { calendar.startOfDay(for: $0.day) == target }
    }

    static func log(_ all: [DoseLog], on day: Date, slot: DoseSlot, calendar: Calendar = .current) -> DoseLog? {
        logs(all, on: day, calendar: calendar).first { $0.slotLabel == slot.label }
    }

    /// Total actually taken on a day, for the dose-over-time chart.
    static func takenTotal(_ all: [DoseLog], on day: Date, calendar: Calendar = .current) -> Double {
        logs(all, on: day, calendar: calendar).reduce(0) { $0 + $1.actualAmount }
    }

    // MARK: Symptoms

    static func checkIns(_ all: [SymptomCheckIn], from start: Date, to end: Date, calendar: Calendar = .current) -> [SymptomCheckIn] {
        let first = calendar.startOfDay(for: start), last = calendar.startOfDay(for: end)
        return all.filter { $0.hasContent && $0.day >= first && $0.day <= last }.sorted { $0.day < $1.day }
    }

    static func series(_ checkIns: [SymptomCheckIn], symptom: Symptom) -> [(day: Date, value: Double)] {
        checkIns.compactMap { c in
            let value = c.rating(symptom)
            return value > 0 ? (c.day, Double(value)) : nil
        }.sorted { $0.day < $1.day }
    }

    static func averageSeverity(_ checkIns: [SymptomCheckIn]) -> Double? {
        let values = checkIns.map(\.severityAverage).filter { $0 > 0 }
        return values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
    }

    /// Symptoms rated at least once, worst average first.
    static func rankedSymptoms(_ checkIns: [SymptomCheckIn]) -> [(symptom: Symptom, average: Double, days: Int)] {
        Symptom.allCases.compactMap { symptom in
            let values = checkIns.map { $0.rating(symptom) }.filter { $0 > 0 }
            guard !values.isEmpty else { return nil }
            return (symptom, Double(values.reduce(0, +)) / Double(values.count), values.count)
        }.sorted { $0.average > $1.average }
    }

    /// The symptoms with enough days rated to draw a line, most-tracked first.
    /// The list of symptoms is ranked by severity; the chart is ranked by coverage.
    static func mostTracked(_ checkIns: [SymptomCheckIn], limit: Int = 3) -> [Symptom] {
        rankedSymptoms(checkIns)
            .sorted { ($0.days, $0.average) > ($1.days, $1.average) }
            .prefix(limit)
            .map(\.symptom)
    }

    /// Average severity in the days just before a step change against the days just after,
    /// so a rough patch can be seen next to the reduction that may explain it.
    static func severityAround(stepStart: Date, checkIns: [SymptomCheckIn], window: Int = 7, calendar: Calendar = .current) -> (before: Double?, after: Double?) {
        let start = calendar.startOfDay(for: stepStart)
        guard let windowStart = calendar.date(byAdding: .day, value: -window, to: start),
              let windowEnd = calendar.date(byAdding: .day, value: window, to: start) else { return (nil, nil) }
        let before = checkIns.filter { $0.day >= windowStart && $0.day < start }
        let after = checkIns.filter { $0.day >= start && $0.day <= windowEnd }
        return (averageSeverity(before), averageSeverity(after))
    }
}
