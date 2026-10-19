import Foundation

/// Summary the app writes to the shared App Group so the widget can render without SwiftData.
struct WidgetSnapshot: Codable {
    var hasPlan: Bool = false
    var medicationName: String = ""
    var stepLabel: String = ""
    var stepNumber: Int = 0
    var stepCount: Int = 0
    var dailyTotal: String = ""
    var dosesTakenToday: Int = 0
    var dosesDueToday: Int = 0
    var nextStepDate: Date?
    var checkedInToday: Bool = false
    var updatedAt: Date = .now

    var todayFraction: Double { dosesDueToday > 0 ? min(Double(dosesTakenToday) / Double(dosesDueToday), 1) : 0 }

    static let storageKey = "widget.snapshot"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: AppConfig.appGroupID) ?? .standard
    }

    static func load() -> WidgetSnapshot {
        guard let data = defaults.data(forKey: storageKey),
              let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data) else { return WidgetSnapshot() }
        return snapshot
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        Self.defaults.set(data, forKey: Self.storageKey)
    }

    static let placeholder = WidgetSnapshot(hasPlan: true, medicationName: "Clonazepam", stepLabel: "0.75 mg a day",
                                            stepNumber: 4, stepCount: 9, dailyTotal: "0.75 mg", dosesTakenToday: 1, dosesDueToday: 2,
                                            nextStepDate: Calendar.current.date(byAdding: .day, value: 9, to: .now), checkedInToday: false)
}
