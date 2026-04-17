import SwiftUI

// MARK: - HomeView

struct HomeView: View {

    @State private var viewModel = HomeViewModel()
    @State private var showLogSheet = false
    @State private var selectedCategory: CarbonCategory = .transport

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {

                    // MARK: Greeting + Score Ring
                    headerSection

                    // MARK: Active Nudges
                    if !viewModel.activeNudges.isEmpty {
                        nudgesSection
                    }

                    // MARK: Today's Breakdown
                    breakdownSection

                    // MARK: Recent Entries
                    if !viewModel.recentEntries.isEmpty {
                        recentEntriesSection
                    }

                    Spacer(minLength: 100)
                }
                .padding(.horizontal)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("GreenCatalyst")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showLogSheet = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.green)
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { viewModel.syncHealthKitData() }) {
                        Image(systemName: "heart.circle")
                            .foregroundStyle(.red)
                    }
                }
            }
            .sheet(isPresented: $showLogSheet) {
                LogEntrySheet(viewModel: viewModel)
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .task { viewModel.onAppear() }
            .refreshable { await viewModel.loadData() }
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Good \(greetingTime), \(viewModel.userProfile.name.components(separatedBy: " ").first ?? "there") 👋")
                        .font(.title2.bold())
                    Text("Level \(viewModel.userProfile.level) · \(viewModel.userProfile.levelTitle)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                ActivityRingView(
                    progress: viewModel.todaySummary.progressPercent,
                    kgCO2: viewModel.todaySummary.totalKgCO2,
                    target: viewModel.todaySummary.targetKgCO2,
                    size: 80
                )
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))

            // Score pill
            HStack(spacing: 20) {
                ScorePill(label: "Today", value: "\(String(format: "%.1f", viewModel.todaySummary.totalKgCO2)) kg", icon: "leaf.fill", tint: .green)
                ScorePill(label: "Saved", value: "£\(String(format: "%.2f", viewModel.todaySummary.costSaved))", icon: "sterlingsign.circle.fill", tint: .blue)
                ScorePill(label: "Points", value: "+\(viewModel.todaySummary.pointsEarned)", icon: "star.fill", tint: .yellow)
            }
        }
    }

    private var nudgesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Today's Nudges", icon: "bell.badge.fill", tint: .orange)
            ForEach(viewModel.activeNudges.prefix(3)) { nudge in
                NudgeCardView(
                    nudge: nudge,
                    onComplete: { viewModel.completeNudge(nudge) },
                    onDismiss:  { viewModel.dismissNudge(nudge) }
                )
            }
        }
    }

    private var breakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Category Breakdown", icon: "chart.pie.fill", tint: .purple)
            DonutChartView(breakdowns: viewModel.todaySummary.byCategory)
                .frame(height: 220)
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private var recentEntriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Recent Entries", icon: "clock.fill", tint: .gray)
            ForEach(viewModel.recentEntries.prefix(5)) { entry in
                EntryRow(entry: entry)
            }
        }
    }

    // MARK: - Helpers

    private var greetingTime: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 0..<12: return "morning"
        case 12..<17: return "afternoon"
        default: return "evening"
        }
    }
}

// MARK: - ScorePill

struct ScorePill: View {
    let label: String
    let value: String
    let icon: String
    let tint: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(tint)
                .font(.title3)
            Text(value)
                .font(.subheadline.bold())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - SectionHeader

struct SectionHeader: View {
    let title: String
    let icon: String
    let tint: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(tint)
            Text(title)
                .font(.headline)
        }
    }
}

// MARK: - EntryRow

struct EntryRow: View {
    let entry: CarbonEntry

    var body: some View {
        HStack {
            Image(systemName: entry.category.icon)
                .foregroundStyle(.white)
                .padding(8)
                .background(Color(hex: entry.category.color))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.notes ?? entry.category.rawValue)
                    .font(.subheadline)
                    .lineLimit(1)
                Text(entry.date.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(String(format: "%.2f", entry.kgCO2)) kg")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(entry.kgCO2 < 0 ? .green : .primary)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - LogEntrySheet

struct LogEntrySheet: View {
    let viewModel: HomeViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedCategory: CarbonCategory = .transport
    @State private var selectedMode: TransportMode = .car
    @State private var distanceText: String = ""
    @State private var manualKgText: String = ""
    @State private var notes: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Category") {
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(CarbonCategory.allCases) { cat in
                            Label(cat.rawValue, systemImage: cat.icon).tag(cat)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if selectedCategory == .transport {
                    Section("Transport") {
                        Picker("Mode", selection: $selectedMode) {
                            ForEach(TransportMode.allCases, id: \.self) { mode in
                                Label(mode.rawValue, systemImage: mode.icon).tag(mode)
                            }
                        }
                        TextField("Distance (km)", text: $distanceText)
                            .keyboardType(.decimalPad)
                    }
                } else {
                    Section("CO₂ Amount") {
                        TextField("kg CO₂e (e.g. 1.5)", text: $manualKgText)
                            .keyboardType(.decimalPad)
                    }
                }

                Section("Notes (optional)") {
                    TextField("Add a note", text: $notes)
                }
            }
            .navigationTitle("Log Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private var canSave: Bool {
        if selectedCategory == .transport {
            return Double(distanceText) != nil
        }
        return Double(manualKgText) != nil
    }

    private func save() {
        if selectedCategory == .transport, let dist = Double(distanceText) {
            viewModel.logTransportEntry(mode: selectedMode, distanceKm: dist)
        } else if let kg = Double(manualKgText) {
            viewModel.logCarbonEntry(
                category: selectedCategory,
                kgCO2: kg,
                notes: notes.isEmpty ? nil : notes
            )
        }
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    HomeView()
}
