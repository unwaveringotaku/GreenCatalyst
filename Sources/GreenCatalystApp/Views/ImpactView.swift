import SwiftUI
import Charts

// MARK: - ImpactView

struct ImpactView: View {

    @State private var viewModel = ImpactViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {

                    // Period Picker
                    periodPicker

                    // Hero Score Card
                    scoreCard

                    // Bar Chart
                    weeklyChart

                    // Category Breakdown
                    categoryBreakdown

                    // Equivalencies
                    if !viewModel.summary.equivalencies.isEmpty {
                        equivalenciesSection
                    }

                    // vs Comparisons
                    comparisonsSection

                    // Export
                    exportSection

                    Spacer(minLength: 80)
                }
                .padding(.horizontal)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Your Impact")
            .navigationBarTitleDisplayMode(.large)
            .task { viewModel.onAppear() }
            .onChange(of: viewModel.selectedPeriod) { _, _ in viewModel.onPeriodChanged() }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    // MARK: - Period Picker

    private var periodPicker: some View {
        Picker("Period", selection: $viewModel.selectedPeriod) {
            ForEach([SummaryPeriod.today, .week, .month, .year], id: \.self) { period in
                Text(period.rawValue).tag(period)
            }
        }
        .pickerStyle(.segmented)
        .padding(.top, 4)
    }

    // MARK: - Score Card

    private var scoreCard: some View {
        VStack(spacing: 16) {
            HStack(alignment: .center, spacing: 24) {
                ActivityRingView(
                    progress: viewModel.summary.progressPercent,
                    kgCO2: viewModel.summary.totalKgCO2,
                    target: viewModel.summary.targetKgCO2,
                    size: 110
                )

                VStack(alignment: .leading, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(format: "%.1f kg", viewModel.summary.totalKgCO2))
                            .font(.title.bold())
                        Text("CO₂ · \(viewModel.selectedPeriod.rawValue.lowercased())")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Divider()

                    HStack(spacing: 12) {
                        MetricBadge(
                            label: "Saved",
                            value: String(format: "%.1f kg", viewModel.summary.totalKgSaved),
                            tint: .green
                        )
                        MetricBadge(
                            label: "£ Saved",
                            value: String(format: "£%.2f", viewModel.summary.costSaved),
                            tint: .blue
                        )
                    }

                    HStack(spacing: 12) {
                        MetricBadge(
                            label: "Points",
                            value: "+\(viewModel.summary.pointsEarned)",
                            tint: .orange
                        )
                        MetricBadge(
                            label: "Habits",
                            value: "\(viewModel.summary.habitsCompleted)",
                            tint: .purple
                        )
                    }
                }
            }

            // Under/Over target banner
            HStack {
                Image(systemName: viewModel.summary.isUnderTarget ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                Text(viewModel.summary.isUnderTarget
                     ? "Under your \(String(format: "%.0f", viewModel.summary.targetKgCO2)) kg target 🎉"
                     : "\(String(format: "%.1f", viewModel.summary.totalKgCO2 - viewModel.summary.targetKgCO2)) kg over target")
                    .font(.subheadline.bold())
                Spacer()
            }
            .foregroundStyle(viewModel.summary.isUnderTarget ? .green : .orange)
            .padding(10)
            .background((viewModel.summary.isUnderTarget ? Color.green : Color.orange).opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Weekly Chart

    @ViewBuilder
    private var weeklyChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Daily CO₂ (last 7 days)", icon: "chart.bar.fill", tint: .green)

            if viewModel.weeklyTotals.isEmpty {
                Text("No data yet. Start logging entries to see your trend.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                Chart(viewModel.weeklyTotals) { day in
                    BarMark(
                        x: .value("Day", day.dayLabel),
                        y: .value("kg CO₂", day.kgCO2)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.green, .mint],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .cornerRadius(6)
                    RuleMark(y: .value("Target", 8.0))
                        .foregroundStyle(.orange.opacity(0.6))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                        .annotation(position: .top, alignment: .leading) {
                            Text("Target")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                }
                .frame(height: 160)
                .chartYAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { val in
                        AxisValueLabel { Text("\(val.as(Double.self).map { String(format: "%.0f", $0) } ?? "")kg") }
                        AxisGridLine()
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Category Breakdown

    private var categoryBreakdown: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "By Category", icon: "chart.pie.fill", tint: .purple)

            if viewModel.summary.byCategory.isEmpty {
                Text("Log entries to see your category breakdown.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                ForEach(viewModel.summary.byCategory.sorted { $0.kgCO2 > $1.kgCO2 }) { breakdown in
                    CategoryBreakdownRow(breakdown: breakdown)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Equivalencies

    private var equivalenciesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "That's equivalent to…", icon: "sparkles", tint: .yellow)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(viewModel.summary.equivalencies) { eq in
                    EquivalencyCard(equivalency: eq)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Comparisons

    private var comparisonsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "How you compare", icon: "person.2.fill", tint: .indigo)

            ComparisonRow(
                label: "vs last \(viewModel.selectedPeriod.rawValue.lowercased())",
                delta: viewModel.summary.vsLastPeriodDelta,
                unit: "kg CO₂"
            )
            ComparisonRow(
                label: "vs national average",
                delta: viewModel.summary.vsNationalAverageDelta,
                unit: "kg CO₂"
            )
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Export

    private var exportSection: some View {
        ShareLink(
            item: viewModel.exportSummaryCSV(),
            preview: SharePreview("GreenCatalyst Carbon Report", icon: Image(systemName: "leaf.fill"))
        ) {
            Label("Export as CSV", systemImage: "square.and.arrow.up")
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green.opacity(0.15))
                .foregroundStyle(.green)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - Supporting Views

struct MetricBadge: View {
    let label: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.subheadline.bold()).foregroundStyle(tint)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }
}

struct CategoryBreakdownRow: View {
    let breakdown: CategoryBreakdown

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: breakdown.category.icon)
                .foregroundStyle(Color(hex: breakdown.category.color))
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(breakdown.category.rawValue).font(.subheadline)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(.systemFill))
                            .frame(height: 6)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(hex: breakdown.category.color))
                            .frame(width: geo.size.width * breakdown.percentOfTotal, height: 6)
                    }
                }
                .frame(height: 6)
            }
            Text(String(format: "%.1f kg", breakdown.kgCO2))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .trailing)
        }
        .padding(.vertical, 4)
    }
}

struct EquivalencyCard: View {
    let equivalency: Equivalency

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: equivalency.icon)
                .foregroundStyle(.green)
                .font(.title3)
            Text(equivalency.label)
                .font(.caption)
                .lineLimit(2)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.green.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct ComparisonRow: View {
    let label: String
    let delta: Double
    let unit: String

    var isImprovement: Bool { delta < 0 }

    var body: some View {
        HStack {
            Text(label).font(.subheadline)
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: isImprovement ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                Text(String(format: "%+.1f %@", delta, unit))
                    .font(.subheadline.monospacedDigit().bold())
            }
            .foregroundStyle(isImprovement ? .green : .orange)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ImpactView()
}
