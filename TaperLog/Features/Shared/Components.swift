import SwiftUI

/// A rounded, grouped-background panel.
struct Panel<Content: View>: View {
    var title: String? = nil
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title { Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary).textCase(.uppercase) }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}

extension Severity {
    var color: Color {
        switch self {
        case .none: return .secondary
        case .mild: return .green
        case .moderate: return .yellow
        case .severe: return .orange
        case .verySevere: return .red
        }
    }
}

extension DoseStatus {
    var color: Color {
        switch self {
        case .taken: return .green
        case .partial: return .orange
        case .skipped: return .red
        }
    }
}

/// None to Very severe as five taps.
struct SeverityPicker: View {
    let symptom: Symptom
    @Binding var value: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(symptom.name).font(.subheadline)
                Spacer()
                Text(Severity(rawValue: value)?.name ?? "None")
                    .font(.caption).foregroundStyle(Severity(rawValue: value)?.color ?? .secondary)
            }
            HStack(spacing: 6) {
                ForEach(Severity.allCases) { level in
                    Button { value = level.rawValue } label: {
                        Text(level.short)
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity).frame(height: 38)
                            .background(value == level.rawValue ? level.color.opacity(0.9) : Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 9))
                            .foregroundStyle(value == level.rawValue ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(symptom.name), \(level.name)")
                    .accessibilityAddTraits(value == level.rawValue ? .isSelected : [])
                }
            }
        }
        .padding(.vertical, 2)
    }
}

/// One scheduled dose on the Today screen, with its three outcomes.
struct DoseRow: View {
    let slot: DoseSlot
    let unit: DoseUnit
    let log: DoseLog?
    let onSet: (DoseStatus) -> Void
    let onOpen: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(slot.label).font(.headline)
                    Text(Formatters.dose(slot.amount, unit: unit)).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                if let log {
                    Button(action: onOpen) {
                        HStack(spacing: 5) {
                            Image(systemName: log.status.symbol)
                            VStack(alignment: .trailing, spacing: 1) {
                                Text(log.status.name).font(.subheadline.weight(.semibold))
                                if let at = log.takenAt { Text(Formatters.time.string(from: at)).font(.caption2) }
                            }
                        }
                        .foregroundStyle(log.status.color)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(slot.label) marked \(log.status.name). Edit.")
                }
            }
            if log == nil {
                HStack(spacing: 8) {
                    ForEach(DoseStatus.allCases) { status in
                        Button { onSet(status) } label: {
                            Label(status.name, systemImage: status.symbol)
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity).frame(height: 42)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(status == .taken ? Color.accentColor : status.color.opacity(0.85))
                        .accessibilityLabel("\(slot.label), \(status.name)")
                    }
                }
            }
        }
    }
}
