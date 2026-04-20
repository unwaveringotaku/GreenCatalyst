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
    let isLauncherOnly: Bool

    static let placeholder = GreenCatalystEntry(
        date: .now,
        kgCO2Today: 0,
        targetKg: 8.0,
        topNudgeTitle: nil,
        topNudgeCO2: 0,
        topStreak: 0,
        isUnderTarget: true,
        isLauncherOnly: true
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
        .placeholder
    }

    func timeline(for configuration: GreenCatalystWidgetIntent, in context: Context) async -> Timeline<GreenCatalystEntry> {
        let entry = GreenCatalystEntry.placeholder
        let refreshDate = Calendar.current.date(byAdding: .hour, value: 6, to: .now) ?? .now
        return Timeline(entries: [entry], policy: .after(refreshDate))
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
        VStack(spacing: 8) {
            Image(systemName: "leaf.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(.green)
            Text("Open the app")
                .font(.caption.bold())
            Text("Use this widget as a quick launcher back into your tracking flow.")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(8)
        .containerBackground(Color(.systemBackground).gradient, for: .widget)
        .widgetURL(URL(string: "greencatalyst://home"))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Open GreenCatalyst")
        .accessibilityHint("Launches the app")
    }
}

// MARK: - Medium Widget View

struct MediumWidgetView: View {
    let entry: GreenCatalystEntry

    var body: some View {
        HStack(spacing: 16) {
            VStack(spacing: 6) {
                Image(systemName: "leaf.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.green)
                Text("Open GreenCatalyst")
                    .font(.headline)
                Text("Jump back into the app quickly to review your latest footprint, habits, and suggestions.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .containerBackground(Color(.systemBackground).gradient, for: .widget)
        .widgetURL(URL(string: "greencatalyst://home"))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Open GreenCatalyst")
        .accessibilityHint("Launches the app")
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
        .description("Open GreenCatalyst from your Home Screen.")
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
