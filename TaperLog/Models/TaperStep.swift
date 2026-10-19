import Foundation
import SwiftData

/// One rung of the schedule: what to take, at which times, from which date.
/// Every number here is typed in by the user from their prescription.
@Model
final class TaperStep {
    var id: UUID = UUID()
    var planID: UUID? = nil
    var orderIndex: Int = 0
    var startDate: Date = Date()
    /// Used for the last step, and to prefill the next step's start date.
    var durationDays: Int = 14
    /// "Morning:1|Evening:0.5" — the dose at each time of day, in the plan's unit.
    var dosesRaw: String = ""
    var notes: String = ""
    var createdAt: Date = Date()

    init(planID: UUID?, orderIndex: Int, startDate: Date, durationDays: Int = 14, doses: [DoseSlot] = []) {
        self.id = UUID()
        self.planID = planID
        self.orderIndex = orderIndex
        self.startDate = Calendar.current.startOfDay(for: startDate)
        self.durationDays = durationDays
        self.dosesRaw = DoseSlot.encode(doses)
        self.createdAt = .now
    }

    var doses: [DoseSlot] {
        get { DoseSlot.decode(dosesRaw) }
        set { dosesRaw = DoseSlot.encode(newValue) }
    }

    var dailyTotal: Double { doses.reduce(0) { $0 + $1.amount } }

    /// "1 mg + 0.5 mg" for a two-dose day.
    func doseSummary(unit: DoseUnit) -> String {
        doses.isEmpty ? "no doses" : doses.map { Formatters.dose($0.amount, unit: unit) }.joined(separator: " + ")
    }
}

/// One scheduled dose within a day.
struct DoseSlot: Identifiable, Hashable {
    var label: String
    var amount: Double
    var id: String { "\(label)-\(amount)" }

    static let commonLabels = ["Morning", "Midday", "Afternoon", "Evening", "Bedtime"]

    static func decode(_ raw: String) -> [DoseSlot] {
        raw.split(separator: "|").compactMap { part in
            let pieces = part.split(separator: ":", maxSplits: 1)
            guard pieces.count == 2, let amount = Double(pieces[1]) else { return nil }
            return DoseSlot(label: String(pieces[0]), amount: amount)
        }
    }

    static func encode(_ slots: [DoseSlot]) -> String {
        slots.map { "\($0.label.replacingOccurrences(of: "|", with: " ").replacingOccurrences(of: ":", with: " ")):\($0.amount)" }
            .joined(separator: "|")
    }
}

/// What happened with one scheduled dose.
@Model
final class DoseLog {
    var id: UUID = UUID()
    var planID: UUID? = nil
    var stepID: UUID? = nil
    /// The day the dose belonged to, at midnight.
    var day: Date = Date()
    var slotLabel: String = ""
    var plannedAmount: Double = 0
    var actualAmount: Double = 0
    var statusRaw: String = DoseStatus.taken.rawValue
    var takenAt: Date? = nil
    var notes: String = ""
    var createdAt: Date = Date()

    init(plan: TaperPlan?, step: TaperStep?, day: Date, slot: DoseSlot, status: DoseStatus = .taken) {
        self.id = UUID()
        self.planID = plan?.id
        self.stepID = step?.id
        self.day = Calendar.current.startOfDay(for: day)
        self.slotLabel = slot.label
        self.plannedAmount = slot.amount
        self.actualAmount = status == .taken ? slot.amount : 0
        self.statusRaw = status.rawValue
        self.takenAt = status == .skipped ? nil : .now
        self.createdAt = .now
    }

    var status: DoseStatus {
        get { DoseStatus(rawValue: statusRaw) ?? .taken }
        set { statusRaw = newValue.rawValue }
    }
}

enum DoseStatus: String, CaseIterable, Identifiable {
    case taken, partial, skipped
    var id: String { rawValue }
    var name: String {
        switch self {
        case .taken: return "Taken"
        case .partial: return "Partial"
        case .skipped: return "Skipped"
        }
    }
    var symbol: String {
        switch self {
        case .taken: return "checkmark.circle.fill"
        case .partial: return "circle.lefthalf.filled"
        case .skipped: return "xmark.circle.fill"
        }
    }
}
