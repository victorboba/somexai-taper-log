import AppIntents
import Foundation

/// "Log a dose in Taper Log" opens the app on Today.
struct LogDoseIntent: AppIntent {
    static var title: LocalizedStringResource = "Log a Dose"
    static var description = IntentDescription("Opens Taper Log on today's doses.")
    static var openAppWhenRun = true

    static let pendingKey = "intent.openToday"

    func perform() async throws -> some IntentResult {
        WidgetSnapshot.defaults.set(true, forKey: Self.pendingKey)
        return .result()
    }
}

struct TaperLogShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: LogDoseIntent(), phrases: ["Log a dose in \(.applicationName)", "Open \(.applicationName)"],
                    shortTitle: "Log Dose", systemImageName: "checkmark.circle")
    }
}
