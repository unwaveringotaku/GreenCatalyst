import SwiftUI

// MARK: - DonutChartView
//
// A native SwiftUI donut (pie) chart using Canvas,
// showing CO₂ by category with a legend.
// Falls back gracefully to empty state.

struct DonutChartView: View {

    let breakdowns: [CategoryBreakdown]

    @State private var selectedIndex: Int? = nil

    private var totalMagnitude: Double {
        breakdowns.reduce(0) { $0 + abs($1.kgCO2) }
    }

    private var netTotal: Double {
        breakdowns.reduce(0) { $0 + $1.kgCO2 }
    }

    var body: some View {
        if breakdowns.isEmpty || totalMagnitude == 0 {
            emptyState
        } else {
            HStack(spacing: 20) {
                donutCanvas
                    .frame(width: 130, height: 130)
                legend
            }
        }
    }

    // MARK: - Donut Canvas

    private var donutCanvas: some View {
        ZStack {
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let radius = min(size.width, size.height) / 2
                let lineWidth: CGFloat = 28
                let innerRadius = radius - lineWidth

                var startAngle = Angle.degrees(-90)
                for (index, breakdown) in breakdowns.enumerated() {
                    let sweep = Angle.degrees(360 * (abs(breakdown.kgCO2) / totalMagnitude))
                    let endAngle = startAngle + sweep
                    let isSelected = selectedIndex == index

                    var path = Path()
                    path.addArc(
                        center: center,
                        radius: radius - (isSelected ? 0 : lineWidth / 2),
                        startAngle: startAngle,
                        endAngle: endAngle,
                        clockwise: false
                    )
                    path.addArc(
                        center: center,
                        radius: innerRadius - (isSelected ? 0 : lineWidth / 2),
                        startAngle: endAngle,
                        endAngle: startAngle,
                        clockwise: true
                    )
                    path.closeSubpath()

                    let color = Color(hex: breakdown.category.color)
                    context.fill(path, with: .color(isSelected ? color : color.opacity(0.85)))
                    startAngle = endAngle
                }
            }
            .contentShape(Rectangle())
            .gesture(
                SpatialTapGesture()
                    .onEnded { value in
                        selectedIndex = hitTest(point: value.location, size: CGSize(width: 130, height: 130))
                    }
            )

            // Centre label
            if let idx = selectedIndex, idx < breakdowns.count {
                VStack(spacing: 2) {
                    Text(breakdowns[idx].category.rawValue)
                        .font(.system(size: 10, weight: .bold))
                        .multilineTextAlignment(.center)
                    Text(String(format: "%.1f kg", breakdowns[idx].kgCO2))
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .frame(width: 70)
            } else {
                VStack(spacing: 2) {
                    Text(String(format: "%.1f", netTotal))
                        .font(.system(size: 16, weight: .bold, design: .rounded).monospacedDigit())
                    Text("kg total")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Legend

    private var legend: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(breakdowns.enumerated()), id: \.element.id) { index, breakdown in
                Button {
                    selectedIndex = (selectedIndex == index) ? nil : index
                } label: {
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color(hex: breakdown.category.color))
                            .frame(width: 12, height: 12)

                        VStack(alignment: .leading, spacing: 0) {
                            Text(breakdown.category.rawValue)
                                .font(.caption.bold())
                                .foregroundStyle(.primary)
                            Text(String(format: "%.0f%%", breakdown.percentOfTotal * 100))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(String(format: "%.1f", breakdown.kgCO2))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                    .background(selectedIndex == index ? Color(hex: breakdown.category.color).opacity(0.1) : .clear)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.pie")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)
            Text("No entries yet today")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 130)
    }

    // MARK: - Hit Testing

    private func hitTest(point: CGPoint, size: CGSize) -> Int? {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let dx = point.x - center.x
        let dy = point.y - center.y
        let dist = sqrt(dx * dx + dy * dy)
        let radius = min(size.width, size.height) / 2
        let lineWidth: CGFloat = 28
        let innerRadius = radius - lineWidth

        guard dist >= innerRadius, dist <= radius else { return nil }

        var angle = atan2(dy, dx) * 180 / .pi + 90
        if angle < 0 { angle += 360 }

        var cumulative = 0.0
        for (index, breakdown) in breakdowns.enumerated() {
            let sweep = 360 * (abs(breakdown.kgCO2) / totalMagnitude)
            if angle >= cumulative && angle < cumulative + sweep { return index }
            cumulative += sweep
        }
        return nil
    }
}

#Preview {
    DonutChartView(breakdowns: ImpactSummary.todaySample.byCategory)
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding()
}
