import Foundation
import SwiftData

/// One medicine being stepped down, exactly as the prescriber wrote it.
/// The app stores this plan; it never generates or adjusts one.
@Model
final class TaperPlan {
    var id: UUID = UUID()
    var medicationName: String = ""
    var formRaw: String = MedicationForm.tablet.rawValue
    var unitRaw: String = DoseUnit.mg.rawValue
    var prescriberName: String = ""
    var clinicName: String = ""
    var startDate: Date = Date()
    var completedDate: Date? = nil
    var isArchived: Bool = false
    var reason: String = ""
    var notes: String = ""
    var createdAt: Date = Date()

    init(medicationName: String, unit: DoseUnit = .mg, form: MedicationForm = .tablet) {
        self.id = UUID()
        self.medicationName = medicationName
        self.unitRaw = unit.rawValue
        self.formRaw = form.rawValue
        self.startDate = Calendar.current.startOfDay(for: .now)
        self.createdAt = .now
    }

    var form: MedicationForm {
        get { MedicationForm(rawValue: formRaw) ?? .tablet }
        set { formRaw = newValue.rawValue }
    }

    var unit: DoseUnit {
        get { DoseUnit(rawValue: unitRaw) ?? .mg }
        set { unitRaw = newValue.rawValue }
    }

    var isActive: Bool { !isArchived && completedDate == nil }

    /// "Clonazepam · tablet · mg"
    var subtitle: String { "\(form.name) · \(unit.rawValue)" }
}

enum MedicationForm: String, CaseIterable, Identifiable {
    case tablet, capsule, liquid, patch, injection, other
    var id: String { rawValue }
    var name: String {
        switch self {
        case .tablet: return "Tablet"
        case .capsule: return "Capsule"
        case .liquid: return "Liquid"
        case .patch: return "Patch"
        case .injection: return "Injection"
        case .other: return "Other"
        }
    }
}

enum DoseUnit: String, CaseIterable, Identifiable {
    case mg, mcg, mL = "mL", g, units = "units", patches = "patches", tablets = "tablets"
    var id: String { rawValue }
    var name: String { rawValue }
}
