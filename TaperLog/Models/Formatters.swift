import Foundation

enum Formatters {
    static let dateTime: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    static let date: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    /// "Wed, Sep 16"
    static let weekdayShort: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d"
        return f
    }()

    /// "Sep 16"
    static let short: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    static let time: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }()

    /// "0.75", trimming trailing zeros so 1.0 reads as 1 and 0.125 survives.
    static func amount(_ value: Double) -> String {
        if value == value.rounded() { return String(Int(value)) }
        let s = String(format: "%.4f", value)
        return s.replacingOccurrences(of: "0+$", with: "", options: .regularExpression)
                .replacingOccurrences(of: "\\.$", with: "", options: .regularExpression)
    }

    /// "0.75 mg"
    static func dose(_ value: Double, unit: DoseUnit) -> String { "\(amount(value)) \(unit.rawValue)" }

    /// "82%"
    static func percent(_ fraction: Double) -> String { "\(Int((fraction * 100).rounded()))%" }

    /// "9 days" / "1 day" / "today"
    static func days(_ count: Int) -> String {
        if count <= 0 { return "today" }
        return count == 1 ? "1 day" : "\(count) days"
    }
}
