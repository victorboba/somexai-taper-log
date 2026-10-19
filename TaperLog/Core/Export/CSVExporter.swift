import Foundation

enum CSVExporter {
    static let doseHeader = "day,step,slot,planned,actual,unit,status,taken_at,notes"
    static let symptomHeader = "day,overall_0_10,sleep_hours,average_severity," + Symptom.allCases.map(\.rawValue).joined(separator: ",") + ",notes"

    static func dosesCSV(_ logs: [DoseLog], plan: TaperPlan, ordered: [TaperStep]) -> String {
        let day = DateFormatter(); day.dateFormat = "yyyy-MM-dd"
        let iso = ISO8601DateFormatter()
        var lines = [doseHeader]
        for log in logs.sorted(by: { ($0.day, $0.slotLabel) < ($1.day, $1.slotLabel) }) {
            let stepNumber = ordered.firstIndex { $0.id == log.stepID }.map { String($0 + 1) } ?? ""
            var row: [String] = [day.string(from: log.day), stepNumber, log.slotLabel]
            row.append(Formatters.amount(log.plannedAmount))
            row.append(Formatters.amount(log.actualAmount))
            row.append(plan.unit.rawValue)
            row.append(log.status.rawValue)
            row.append(log.takenAt.map { iso.string(from: $0) } ?? "")
            row.append(log.notes)
            lines.append(row.map(quote).joined(separator: ","))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    static func symptomsCSV(_ checkIns: [SymptomCheckIn]) -> String {
        let day = DateFormatter(); day.dateFormat = "yyyy-MM-dd"
        var lines = [symptomHeader]
        for c in checkIns.sorted(by: { $0.day < $1.day }) {
            var row: [String] = [day.string(from: c.day)]
            row.append(c.overall == 0 ? "" : String(c.overall))
            row.append(c.sleepHours.map { Formatters.amount($0) } ?? "")
            row.append(c.severityAverage == 0 ? "" : String(format: "%.2f", c.severityAverage))
            row += Symptom.allCases.map { c.rating($0) == 0 ? "" : String(c.rating($0)) }
            row.append(c.notes)
            lines.append(row.map(quote).joined(separator: ","))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    static func write(_ csv: String, suffix: String) throws -> URL {
        let url = ExportFile.temporaryURL(suffix: suffix, extension: "csv")
        try csv.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    static func quote(_ field: String) -> String {
        "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}

/// A file URL wrapped so it can drive `.sheet(item:)`.
struct ExportFile: Identifiable {
    let url: URL
    var id: String { url.path }

    static func temporaryURL(suffix: String, extension ext: String) -> URL {
        let stamp = DateFormatter.fileStamp.string(from: .now)
        return FileManager.default.temporaryDirectory
            .appendingPathComponent("\(AppConfig.exportFileStem)-\(suffix)-\(stamp)")
            .appendingPathExtension(ext)
    }
}

extension DateFormatter {
    static let fileStamp: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd-HHmm"
        return f
    }()
}
