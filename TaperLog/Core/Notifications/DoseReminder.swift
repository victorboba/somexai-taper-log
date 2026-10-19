import Foundation
import UserNotifications

/// A daily reminder at each dose time in the current step, plus an optional evening check-in nudge.
/// Times come from the user; the app never invents a schedule.
enum DoseReminder {
    static let enabledKey = "reminder.dose.enabled"
    static let checkInEnabledKey = "reminder.checkin.enabled"
    static let checkInHourKey = "reminder.checkin.hour"
    static let prefix = "dose.slot."
    static let checkInIdentifier = "checkin.daily"

    /// The hour each named slot fires at, editable by the user in Settings.
    static func hour(for label: String) -> Int {
        let key = "reminder.slot.\(label.lowercased())"
        if UserDefaults.standard.object(forKey: key) != nil { return UserDefaults.standard.integer(forKey: key) }
        switch label.lowercased() {
        case "morning": return 8
        case "midday": return 12
        case "afternoon": return 15
        case "evening": return 19
        case "bedtime": return 22
        default: return 9
        }
    }

    static func setHour(_ hour: Int, for label: String) {
        UserDefaults.standard.set(hour, forKey: "reminder.slot.\(label.lowercased())")
    }

    static var isEnabled: Bool { UserDefaults.standard.bool(forKey: enabledKey) }
    static var checkInEnabled: Bool { UserDefaults.standard.bool(forKey: checkInEnabledKey) }
    static var checkInHour: Int { UserDefaults.standard.object(forKey: checkInHourKey) == nil ? 20 : UserDefaults.standard.integer(forKey: checkInHourKey) }

    static func ensurePermission() async -> Bool {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-uiTesting") { return false }
        #endif
        let center = UNUserNotificationCenter.current()
        switch await center.notificationSettings().authorizationStatus {
        case .notDetermined: return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        case .denied: return false
        default: return true
        }
    }

    static func reschedule(plan: TaperPlan?, steps: [TaperStep], now: Date = .now) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix(prefix) } + [checkInIdentifier])
        guard let plan, plan.isActive, await ensurePermission() else { return }
        let ordered = TaperMath.steps(steps, for: plan)

        if isEnabled, let current = TaperMath.step(on: now, in: ordered) {
            for slot in current.doses {
                var components = DateComponents()
                components.hour = hour(for: slot.label)
                components.minute = 0
                let content = UNMutableNotificationContent()
                content.title = "\(slot.label) dose"
                content.body = "\(plan.medicationName) \(Formatters.dose(slot.amount, unit: plan.unit)), as on your schedule."
                content.sound = .default
                try? await center.add(UNNotificationRequest(identifier: "\(prefix)\(slot.label)", content: content,
                                                             trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)))
            }
        }

        if checkInEnabled {
            var components = DateComponents()
            components.hour = checkInHour
            components.minute = 0
            let content = UNMutableNotificationContent()
            content.title = AppConfig.appName
            content.body = "How has today been? A quick check-in keeps the picture complete."
            content.sound = .default
            try? await center.add(UNNotificationRequest(identifier: checkInIdentifier, content: content,
                                                         trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)))
        }
    }

    static func cancelAll() {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            center.removePendingNotificationRequests(withIdentifiers: requests.map(\.identifier))
        }
    }
}
