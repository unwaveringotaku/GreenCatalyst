import SwiftUI

// MARK: - HomeView

struct HomeView: View {

    @State private var viewModel = HomeViewModel()
    @State private var showLogSheet = false
    @State private var showLevelInfo = false
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
            .sheet(isPresented: $showLevelInfo) {
                NavigationStack {
                    LevelInfoSheet(
                        currentLevel: viewModel.userProfile.level,
                        currentTitle: viewModel.userProfile.levelTitle,
                        pointsToNextLevel: viewModel.userProfile.pointsToNextLevel
                    )
                }
                .presentationDetents([.medium, .large])
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .task { viewModel.onAppear() }
            .onReceive(NotificationCenter.default.publisher(for: .habitDataDidChange)) { _ in
                Task { await viewModel.loadData() }
            }
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
                    Button {
                        showLevelInfo = true
                    } label: {
                        HStack(spacing: 4) {
                            Text("Level \(viewModel.userProfile.level) · \(viewModel.userProfile.levelTitle)")
                            Image(systemName: "info.circle")
                                .font(.caption)
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
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

// MARK: - LevelInfoSheet

struct LevelInfoSheet: View {
    let currentLevel: Int
    let currentTitle: String
    let pointsToNextLevel: Int
    @Environment(\.dismiss) private var dismiss

    private let levels: [(name: String, threshold: Int, purpose: String)] = [
        ("Seedling", 0, "Learn the basics and start building your streak."),
        ("Sprout", 100, "Show early consistency with greener daily choices."),
        ("Sapling", 300, "Turn low-carbon actions into reliable habits."),
        ("Tree", 600, "Make sustainability part of your normal routine."),
        ("Forest Guardian", 1000, "Lead with strong long-term impact across days and weeks."),
        ("Carbon Champion", 3000, "Reach expert-level consistency and climate impact.")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("How Levels Work")
                            .font(.headline)
                        Text("Levels track long-term consistency. You move up by earning points from completed nudges and low-carbon actions.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(.green)
                }

                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Current")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Level \(currentLevel) · \(currentTitle)")
                            .font(.subheadline.bold())
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Next Step")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(pointsToNextLevel > 0 ? "\(pointsToNextLevel) pts to next level" : "Top level reached")
                            .font(.subheadline.bold())
                            .foregroundStyle(.green)
                    }
                }

                VStack(spacing: 8) {
                    ForEach(Array(levels.enumerated()), id: \.offset) { index, level in
                        HStack(alignment: .top, spacing: 10) {
                            Text("\(index + 1)")
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                                .frame(width: 22, height: 22)
                                .background(index + 1 == currentLevel ? Color.green : Color.gray.opacity(0.5))
                                .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(level.name) · \(level.threshold)+ pts")
                                    .font(.subheadline.bold())
                                Text(level.purpose)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Level Guide")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
        }
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
                Section {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 12) {
                            Image(systemName: selectedCategory.icon)
                                .font(.title2)
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .background(Color(hex: selectedCategory.color))
                                .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 3) {
                                Text("Quick Carbon Log")
                                    .font(.headline)
                                Text("Capture a single action without leaving the home flow.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Estimated impact")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(String(format: "%.2f kg CO₂e", estimatedKg))
                                .font(.title3.bold())
                            Text(impactDescription)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.tertiarySystemFill))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
                .listRowBackground(Color.clear)

                Section("Category") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(CarbonCategory.allCases) { category in
                                categoryChip(for: category)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                if selectedCategory == .transport {
                    Section("Transport Details") {
                        Picker("Mode", selection: $selectedMode) {
                            ForEach(TransportMode.allCases, id: \.self) { mode in
                                Label(mode.rawValue, systemImage: mode.icon).tag(mode)
                            }
                        }
                        .pickerStyle(.navigationLink)

                        LabeledContent("Distance (km)") {
                            TextField("e.g. 14.5", text: $distanceText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 90)
                        }

                        Label(
                            "\(selectedMode.rawValue) emits \(String(format: "%.3f", selectedMode.kgPerKm)) kg per km",
                            systemImage: selectedMode.icon
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                } else {
                    Section("Entry Details") {
                        LabeledContent("CO₂ amount (kg)") {
                            TextField("e.g. 1.5", text: $manualKgText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 90)
                        }

                        Label("Use your best estimate for this one-off activity.", systemImage: "chart.bar.doc.horizontal")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Notes (optional)") {
                    TextField("What was this for?", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("New Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
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

    private var estimatedKg: Double {
        if selectedCategory == .transport {
            return (Double(distanceText) ?? 0) * selectedMode.kgPerKm
        }
        return Double(manualKgText) ?? 0
    }

    private var impactDescription: String {
        if selectedCategory == .transport {
            return "Based on \(selectedMode.rawValue.lowercased()) over \(distanceText.isEmpty ? "0" : distanceText) km."
        }
        return "This amount will be added to your \(selectedCategory.rawValue.lowercased()) footprint."
    }

    @ViewBuilder
    private func categoryChip(for category: CarbonCategory) -> some View {
        Button {
            selectedCategory = category
        } label: {
            VStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(.title3)
                    .foregroundStyle(selectedCategory == category ? .white : Color(hex: category.color))
                    .frame(width: 42, height: 42)
                    .background(selectedCategory == category ? Color(hex: category.color) : Color(.tertiarySystemFill))
                    .clipShape(Circle())

                Text(category.rawValue)
                    .font(.caption.bold())
                    .foregroundStyle(.primary)
            }
            .frame(width: 78)
        }
        .buttonStyle(.plain)
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
