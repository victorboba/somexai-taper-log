import WidgetKit
import SwiftUI

struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct SnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry { SnapshotEntry(date: .now, snapshot: .placeholder) }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        completion(SnapshotEntry(date: .now, snapshot: context.isPreview ? .placeholder : WidgetSnapshot.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        let calendar = Calendar.current
        let midnight = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: .now) ?? .now)
        completion(Timeline(entries: [SnapshotEntry(date: .now, snapshot: WidgetSnapshot.load())], policy: .after(midnight)))
    }
}

struct TaperLogWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SnapshotEntry
    private var s: WidgetSnapshot { entry.snapshot }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(s.hasPlan ? s.medicationName : AppConfig.appName)
                .font(.caption.weight(.semibold)).foregroundStyle(.secondary).lineLimit(1)
            if !s.hasPlan {
                Text("Set up your plan").font(.headline)
            } else {
                Text(s.stepLabel).font(.system(size: family == .systemSmall ? 20 : 24, weight: .bold, design: .rounded)).lineLimit(1).minimumScaleFactor(0.7)
                if s.stepCount > 0 {
                    Text("Step \(s.stepNumber) of \(s.stepCount)").font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                if s.dosesDueToday > 0 {
                    HStack(spacing: 5) {
                        Image(systemName: s.dosesTakenToday >= s.dosesDueToday ? "checkmark.circle.fill" : "circle.dashed")
                            .foregroundStyle(s.dosesTakenToday >= s.dosesDueToday ? .green : .orange)
                        Text("\(s.dosesTakenToday) of \(s.dosesDueToday) today").font(.caption)
                    }
                } else {
                    Text("No doses scheduled today").font(.caption2).foregroundStyle(.secondary)
                }
                if family != .systemSmall, let next = s.nextStepDate {
                    let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: entry.date), to: next).day ?? 0
                    Text(days <= 0 ? "Next step today" : "Next step in \(days)d").font(.caption2).foregroundStyle(.secondary)
                }
                if !s.checkedInToday {
                    Text("Check-in not done").font(.caption2).foregroundStyle(.orange)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct TaperLogWidget: Widget {
    let kind = "TaperLogWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SnapshotProvider()) { TaperLogWidgetView(entry: $0) }
            .configurationDisplayName(AppConfig.appName)
            .description("Today's dose from your schedule, and whether you have ticked it off.")
            .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct TaperLogWidgetBundle: WidgetBundle {
    var body: some Widget { TaperLogWidget() }
}
