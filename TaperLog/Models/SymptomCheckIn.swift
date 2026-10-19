import Foundation
import SwiftData

/// One day's check-in. Severities are the user's own rating, nothing is inferred.
@Model
final class SymptomCheckIn {
    var id: UUID = UUID()
    var planID: UUID? = nil
    var day: Date = Date()
    /// "sleep:2|anxiety:3" — only the symptoms the user rated above zero are kept.
    var ratingsRaw: String = ""
    /// 0 (worst) to 10 (best); 0 means not answered.
    var overall: Int = 0
    var sleepHours: Double? = nil
    var notes: String = ""
    var createdAt: Date = Date()

    init(plan: TaperPlan?, day: Date = .now) {
        self.id = UUID()
        self.planID = plan?.id
        self.day = Calendar.current.startOfDay(for: day)
        self.createdAt = .now
    }

    var ratings: [Symptom: Int] {
        get {
            var result: [Symptom: Int] = [:]
            for part in ratingsRaw.split(separator: "|") {
                let pieces = part.split(separator: ":", maxSplits: 1)
                guard pieces.count == 2, let symptom = Symptom(rawValue: String(pieces[0])), let value = Int(pieces[1]) else { continue }
                result[symptom] = value
            }
            return result
        }
        set {
            ratingsRaw = Symptom.allCases.compactMap { symptom in
                guard let value = newValue[symptom], value > 0 else { return nil }
                return "\(symptom.rawValue):\(value)"
            }.joined(separator: "|")
        }
    }

    func rating(_ symptom: Symptom) -> Int { ratings[symptom] ?? 0 }

    /// Mean of the rated symptoms, 0 when nothing was rated.
    var severityAverage: Double {
        let values = ratings.values.filter { $0 > 0 }
        return values.isEmpty ? 0 : Double(values.reduce(0, +)) / Double(values.count)
    }

    var worst: (symptom: Symptom, value: Int)? {
        ratings.filter { $0.value > 0 }.max { $0.value < $1.value }.map { ($0.key, $0.value) }
    }

    var hasContent: Bool { !ratingsRaw.isEmpty || overall > 0 || sleepHours != nil || !notes.isEmpty }
}

/// The symptoms people are usually asked about while stepping a medicine down.
enum Symptom: String, CaseIterable, Identifiable {
    case sleep, anxiety, mood, nausea, headache, dizziness, tremor, sweating, irritability, brainFog, musclePain, appetite, heartRacing, sensitivity

    var id: String { rawValue }

    var name: String {
        switch self {
        case .sleep: return "Trouble sleeping"
        case .anxiety: return "Anxiety"
        case .mood: return "Low mood"
        case .nausea: return "Nausea"
        case .headache: return "Headache"
        case .dizziness: return "Dizziness"
        case .tremor: return "Tremor or shakiness"
        case .sweating: return "Sweating"
        case .irritability: return "Irritability"
        case .brainFog: return "Brain fog"
        case .musclePain: return "Muscle or joint pain"
        case .appetite: return "Appetite change"
        case .heartRacing: return "Racing heart"
        case .sensitivity: return "Light or sound sensitivity"
        }
    }

    var short: String {
        switch self {
        case .sleep: return "Sleep"
        case .anxiety: return "Anxiety"
        case .mood: return "Mood"
        case .nausea: return "Nausea"
        case .headache: return "Headache"
        case .dizziness: return "Dizziness"
        case .tremor: return "Tremor"
        case .sweating: return "Sweating"
        case .irritability: return "Irritable"
        case .brainFog: return "Brain fog"
        case .musclePain: return "Pain"
        case .appetite: return "Appetite"
        case .heartRacing: return "Heart"
        case .sensitivity: return "Sensitivity"
        }
    }

    /// The handful shown at the top of the check-in; the rest are behind "More".
    static var common: [Symptom] { [.sleep, .anxiety, .mood, .nausea, .headache, .dizziness] }
}

enum Severity: Int, CaseIterable, Identifiable {
    case none = 0, mild = 1, moderate = 2, severe = 3, verySevere = 4
    var id: Int { rawValue }
    var name: String {
        switch self {
        case .none: return "None"
        case .mild: return "Mild"
        case .moderate: return "Moderate"
        case .severe: return "Severe"
        case .verySevere: return "Very severe"
        }
    }
    var short: String {
        switch self {
        case .none: return "–"
        case .mild: return "1"
        case .moderate: return "2"
        case .severe: return "3"
        case .verySevere: return "4"
        }
    }
}
