import SwiftUI
import ClockKit

// MARK: - WatchComplicationView
//
// Provides complication views for all watchOS complication families.
// Uses the ClockKit ComplicationDescriptor approach for watchOS 9+.

struct WatchComplicationView: View {

    let store: WatchDataStore

    // The complication family drives which layout to show.
    var family: ComplicationFamily = .graphicCircular

    var body: some View {
        switch family {
        case .graphicCircular:
            graphicCircular
        case .graphicRectangular:
            graphicRectangular
        case .graphicCorner:
            graphicCorner
        case .modularSmall:
            modularSmall
        default:
            graphicCircular
        }
    }

    // MARK: - Circular

    private var graphicCircular: some View {
        ZStack {
            // Progress ring
            Circle()
                .stroke(Color.green.opacity(0.25), lineWidth: 4)
            Circle()
                .trim(from: 0, to: store.progress)
                .stroke(Color.green, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear, value: store.progress)

            // Centre text
            VStack(spacing: 0) {
                Text(String(format: "%.0f", store.kgCO2Today))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text("kg")
                    .font(.system(size: 7))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 44, height: 44)
    }

    // MARK: - Rectangular

    private var graphicRectangular: some View {
        HStack(spacing: 8) {
            // Mini ring
            ZStack {
                Circle()
                    .stroke(Color.green.opacity(0.25), lineWidth: 3)
                Circle()
                    .trim(from: 0, to: store.progress)
                    .stroke(Color.green, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(String(format: "%.1f kg", store.kgCO2Today))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                Text(store.isUnderTarget ? "Under target 🌿" : "Over target ⚠️")
                    .font(.system(size: 10))
                    .foregroundStyle(store.isUnderTarget ? .green : .orange)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Corner

    private var graphicCorner: some View {
        ZStack {
            // Arc progress
            Circle()
                .trim(from: 0.05, to: 0.45)
                .stroke(Color.green.opacity(0.3), lineWidth: 5)
                .rotationEffect(.degrees(-90))
            Circle()
                .trim(from: 0.05, to: max(0.05, 0.45 * store.progress))
                .stroke(Color.green, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))

            VStack(spacing: 0) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.green)
                Text(String(format: "%.0f", store.kgCO2Today))
                    .font(.system(size: 11, weight: .bold))
            }
        }
    }

    // MARK: - Modular Small

    private var modularSmall: some View {
        VStack(spacing: 2) {
            Image(systemName: "leaf.fill")
                .foregroundStyle(.green)
                .font(.system(size: 12))
            Text(String(format: "%.1f", store.kgCO2Today))
                .font(.system(size: 14, weight: .bold).monospacedDigit())
            Text("kg CO₂")
                .font(.system(size: 8))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - ComplicationFamily (Abstraction)

/// A simplified enum to avoid ClockKit import issues in SwiftUI preview.
enum ComplicationFamily {
    case graphicCircular
    case graphicRectangular
    case graphicCorner
    case modularSmall
}

// MARK: - ComplicationController (ClockKit Entry Point)

// NOTE: In your Xcode project, add a Complication target and
// implement CLKComplicationDataSource. The views above are used
// as SwiftUI complication templates via CLKComplicationTemplateGraphicCircularView etc.
//
// Example usage in CLKComplicationDataSource:
//
// func getCurrentTimelineEntry(for complication: CLKComplication,
//                              withHandler handler: @escaping (CLKComplicationTimelineEntry?) -> Void) {
//     let store = WatchDataStore.shared
//     let view = WatchComplicationView(store: store, family: .graphicCircular)
//     let template = CLKComplicationTemplateGraphicCircularView(view)
//     handler(CLKComplicationTimelineEntry(date: .now, complicationTemplate: template))
// }

#Preview {
    HStack(spacing: 20) {
        WatchComplicationView(store: WatchDataStore.shared, family: .graphicCircular)
        WatchComplicationView(store: WatchDataStore.shared, family: .modularSmall)
    }
    .padding()
}
