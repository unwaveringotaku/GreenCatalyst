import WidgetKit
import SwiftUI
import AppIntents

// MARK: - WidgetEntry

struct GreenCatalystEntry: TimelineEntry {
    let date: Date
    let kgCO2Today: Double
    let targetKg: Double
    let topNudgeTitle: String?
    let topNudgeCO2: Double
    let topStreak: Int
    let isUnderTarget: Bool

    static let placeholder = GreenCatalystEntry(
        date: .now,
        kgCO2Today: 4.6,
        targetKg: 8.0,
        topNudgeTitle: "Cycle to work today",
        topNudgeCO2: 2.4,
        topStreak: 5,
        isUnderTarget: true
    )

    var progressFraction: Double {
        guard targetKg > 0 else { return 0 }
        return min(kgCO2Today / targetKg, 1.0)
    }

    var ringColor: Color {
        switch progressFraction {
        case ..<0.5:  return .green
        case ..<0.75: return .yellow
        case ..<1.0:  return .orange
        default:      return .red
        }
    }
}

// MARK: - Provider

struct GreenCatalystProvider: AppIntentTimelineProvider {

    typealias Intent = GreenCatalystWidgetIntent
    typealias Entry = GreenCatalystEntry

    func placeholder(in context: Context) -> GreenCatalystEntry {
        .placeholder
    }

    func snapshot(for configuration: GreenCatalystWidgetIntent, in context: Context) async -> GreenCatalystEntry {
        await fetchEntry()
    }

    func timeline(for configuration: GreenCatalystWidgetIntent, in context: Context) async -> Timeline<GreenCatalystEntry> {
        let entry = await fetchEntry()
        // Refresh at midnight and every hour
        let midnight = Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: 1, to: .now)!)
        let nextHour = Calendar.current.date(byAdding: .hour, value: 1, to: .now)!
        let refreshDate = min(midnight, nextHour)
        return Timeline(entries: [entry], policy: .after(refreshDate))
    }

    // MARK: - Fetch

    @MainActor
    private func fetchEntry() async -> GreenCatalystEntry {
        do {
            let store = DataStore.shared
            let entries = try await store.fetchTodaysEntries()
            let profile = try await store.fetchUserProfile()
            let nudges = try await store.fetchActiveNudges()
            let habits = try await store.fetchHabits()

            let total = entries.reduce(0.0) { $0 + max(0, $1.kgCO2) }
            let topNudge = nudges.sorted { $0.priority > $1.priority }.first
            let topStreak = habits.map { $0.streakCount }.max() ?? 0

            return GreenCatalystEntry(
                date: .now,
                kgCO2Today: total,
                targetKg: profile.targetKgPerDay,
                topNudgeTitle: topNudge?.title,
                topNudgeCO2: topNudge?.co2Saving ?? 0,
                topStreak: topStreak,
                isUnderTarget: total <= profile.targetKgPerDay
            )
        } catch {
            return .placeholder
        }
    }
}

// MARK: - Intent

struct GreenCatalystWidgetIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "GreenCatalyst Widget"
    static let description = IntentDescription("Shows your daily CO₂ footprint.")
}

// MARK: - Small Widget View

struct SmallWidgetView: View {
    let entry: GreenCatalystEntry

    var body: some View {
        ZStack {
            // Background
            ContainerRelativeShape()
                .fill(Color(.systemBackground).gradient)

            VStack(spacing: 6) {
                // Mini ring
                ZStack {
                    Circle()
                        .stroke(entry.ringColor.opacity(0.2), lineWidth: 6)
                    Circle()
                        .trim(from: 0, to: entry.progressFraction)
                        .stroke(
                            AngularGradient(colors: [entry.ringColor, entry.ringColor.opacity(0.6)],
                                            center: .center,
                                            startAngle: .degrees(-90),
                                            endAngle: .degrees(270)),
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 0) {
                        Text(String(format: "%.1f", entry.kgCO2Today))
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .monospacedDigit()
                        Text("kg")
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 72, height: 72)

                // Status label
                Label(entry.isUnderTarget ? "On Track" : "Over", systemImage: entry.isUnderTarget ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .font(.caption2.bold())
                    .foregroundStyle(entry.isUnderTarget ? .green : .orange)
            }
            .padding(8)
        }
        .widgetURL(URL(string: "greencatalyst://home"))
    }
}

// MARK: - Medium Widget View

struct MediumWidgetView: View {
    let entry: GreenCatalystEntry

    var body: some View {
        ZStack {
            ContainerRelativeShape()
                .fill(Color(.systemBackground).gradient)

            HStack(spacing: 16) {
                // Left: Ring
                ZStack {
                    Circle()
                        .stroke(entry.ringColor.opacity(0.2), lineWidth: 8)
                    Circle()
                        .trim(from: 0, to: entry.progressFraction)
                        .stroke(
                            AngularGradient(colors: [entry.ringColor, entry.ringColor.opacity(0.6)],
                                            center: .center,
                                            startAngle: .degrees(-90),
                                            endAngle: .degrees(270)),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 2) {
                        Text(String(format: "%.1f", entry.kgCO2Today))
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .monospacedDigit()
                        Text("of \(String(format: "%.0f", entry.targetKg)) kg")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 90, height: 90)

                // Right: Nudge + Streak
                VStack(alignment: .leading, spacing: 8) {

                    // Streak
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill").foregroundStyle(.orange).font(.caption)
                        Text("\(entry.topStreak) day streak")
                            .font(.caption.bold())
                    }

                    Divider()

                    // Top Nudge
                    if let nudge = entry.topNudgeTitle {
                        VStack(alignment: .leading, spacing: 3) {
                            Label("Today's Nudge", systemImage: "bell.badge.fill")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.orange)
                            Text(nudge)
                                .font(.caption)
                                .lineLimit(2)
                                .foregroundStyle(.primary)
                            if entry.topNudgeCO2 > 0 {
                                Label(String(format: "Saves %.1f kg CO₂", entry.topNudgeCO2), systemImage: "leaf.fill")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.green)
                            }
                        }
                    } else {
                        Text("No nudges today 🌿")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    // Status
                    Label(
                        entry.isUnderTarget ? "Under target" : "Over target",
                        systemImage: entry.isUnderTarget ? "checkmark.circle.fill" : "exclamationmark.circle.fill"
                    )
                    .font(.caption2.bold())
                    .foregroundStyle(entry.isUnderTarget ? .green : .orange)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
        }
        .widgetURL(URL(string: "greencatalyst://home"))
    }
}

// MARK: - Widget Configuration

struct GreenCatalystWidget: Widget {
    let kind: String = "GreenCatalystWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: GreenCatalystWidgetIntent.self, provider: GreenCatalystProvider()) { entry in
            GreenCatalystWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("GreenCatalyst")
        .description("Track your daily carbon footprint at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

// MARK: - Entry View Router

struct GreenCatalystWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: GreenCatalystEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

// MARK: - Widget Bundle

@main
struct GreenCatalystWidgetBundle: WidgetBundle {
    var body: some Widget {
        GreenCatalystWidget()
    }
}

// MARK: - Previews

#Preview(as: .systemSmall) {
    GreenCatalystWidget()
} timeline: {
    GreenCatalystEntry.placeholder
}

#Preview(as: .systemMedium) {
    GreenCatalystWidget()
} timeline: {
    GreenCatalystEntry.placeholder
}
