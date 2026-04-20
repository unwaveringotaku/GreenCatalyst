import SwiftUI

// MARK: - HomeView

struct HomeView: View {

    @State private var viewModel = HomeViewModel()
    @State private var showLogSheet = false
    @State private var showLevelInfo = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {

                    // MARK: Greeting + Score Ring
                    headerSection

                    impactMeaningSection

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
                    .accessibilityLabel("Add entry")
                    .accessibilityHint("Opens the guided carbon log")
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { viewModel.syncHealthKitData() }) {
                        Image(systemName: "heart.circle")
                            .foregroundStyle(.red)
                    }
                    .accessibilityLabel("Import HealthKit trips")
                    .accessibilityHint("Imports estimated trips from workout data")
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
            .onReceive(NotificationCenter.default.publisher(for: .carbonDataDidChange)) { _ in
                Task { await viewModel.loadData() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .nudgeCompleted)) { notification in
                guard let idString = notification.object as? String else { return }
                viewModel.handleCompletedNudgeNotification(idString: idString)
            }
            .onReceive(NotificationCenter.default.publisher(for: .habitLogRequested)) { notification in
                guard let idString = notification.object as? String else { return }
                viewModel.handleHabitLogNotification(idString: idString)
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
                    .accessibilityLabel("Level \(viewModel.userProfile.level), \(viewModel.userProfile.levelTitle)")
                    .accessibilityHint("Opens the level guide")
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
                ScorePill(label: "Budget", value: budgetPillValue, icon: "target", tint: .green)
                ScorePill(
                    label: "Money",
                    value: DisplayFormatting.currency(
                        viewModel.todaySummary.costSaved,
                        currencyCode: viewModel.userProfile.currencyCode
                    ),
                    icon: "banknote.fill",
                    tint: .blue
                )
                ScorePill(label: "Wins", value: "\(actionsToday)", icon: "checkmark.circle.fill", tint: .yellow)
            }
        }
    }

    private var impactMeaningSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "What This Means Today", icon: "text.bubble.fill", tint: .green)

            VStack(alignment: .leading, spacing: 14) {
                HomeInsightRow(icon: "target", title: impactHeadline, detail: impactDetail)
                HomeInsightRow(icon: "banknote.fill", title: savingsHeadline, detail: savingsDetail)
                HomeInsightRow(icon: largestCategoryIcon, title: "Where to focus next", detail: largestCategoryMessage)
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private var nudgesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Helpful Right Now", icon: "bell.badge.fill", tint: .orange)
            Text("These prompts now call out timing and trip context. Schedule-linked triggering is still a follow-up integration.")
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(viewModel.activeNudges.prefix(3)) { nudge in
                NudgeCardView(
                    nudge: nudge,
                    region: viewModel.userProfile.resolvedRegion,
                    onComplete: { viewModel.completeNudge(nudge) },
                    onDismiss:  { viewModel.dismissNudge(nudge) }
                )
            }
        }
    }

    private var breakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Emissions by Category", icon: "chart.pie.fill", tint: .purple)
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

    private var actionsToday: Int {
        viewModel.todaySummary.habitsCompleted + viewModel.todaySummary.nudgesActedOn
    }

    private var budgetPillValue: String {
        if viewModel.todaySummary.totalKgCO2 < 0 {
            return "Net saving"
        }

        if viewModel.todaySummary.isUnderTarget {
            return DisplayFormatting.carbon(viewModel.todaySummary.remainingBudgetKg)
        }

        return "Over \(DisplayFormatting.carbon(viewModel.todaySummary.totalKgCO2 - viewModel.todaySummary.targetKgCO2))"
    }

    private var impactHeadline: String {
        if viewModel.todaySummary.totalKgCO2 < 0 {
            return "Your lower-impact choices are currently outweighing your logged emissions."
        }

        if viewModel.todaySummary.isUnderTarget {
            return "You are \(String(format: "%.1f", viewModel.todaySummary.remainingBudgetKg)) kg under today’s goal."
        }

        return "You are \(String(format: "%.1f", viewModel.todaySummary.totalKgCO2 - viewModel.todaySummary.targetKgCO2)) kg over today’s goal."
    }

    private var impactDetail: String {
        var details: [String] = []

        if let distanceText = savedDrivingEquivalentText {
            details.append("That is like \(distanceText) of driving avoided")
        }

        if actionsToday > 0 {
            details.append("\(actionsToday) lower-impact win\(actionsToday == 1 ? "" : "s") logged")
        }

        return details.isEmpty ? "Start with one trip, meal, or habit to build a daily story." : details.joined(separator: " • ")
    }

    private var savingsHeadline: String {
        if viewModel.todaySummary.costSaved > 0 {
            return "You have saved about \(DisplayFormatting.currency(viewModel.todaySummary.costSaved, currencyCode: viewModel.userProfile.currencyCode)) so far today."
        }

        return "Money can be a better motivator than guilt."
    }

    private var savingsDetail: String {
        if viewModel.todaySummary.costSaved > 0 {
            return "GreenCatalyst now foregrounds savings so cleaner choices feel practical as well as lower impact."
        }

        return "Track habits and nudges to surface cheaper choices alongside the carbon math."
    }

    private var largestCategoryIcon: String {
        viewModel.todaySummary.byCategory.max { abs($0.kgCO2) < abs($1.kgCO2) }?.category.icon ?? "sparkles"
    }

    private var largestCategoryMessage: String {
        guard let category = viewModel.todaySummary.byCategory.max(by: { abs($0.kgCO2) < abs($1.kgCO2) }) else {
            return "Once you log a few actions, this will point to the category with the biggest effect."
        }

        if category.kgCO2 >= 0 {
            return "\(category.category.rawValue) is contributing the most right now at \(String(format: "%.1f", category.kgCO2)) kg. That is the clearest place to improve next."
        }

        return "\(category.category.rawValue) is doing the most work for you so far with \(String(format: "%.1f", abs(category.kgCO2))) kg of savings."
    }

    private var savedDrivingEquivalentText: String? {
        guard viewModel.todaySummary.totalKgSaved > 0 else { return nil }
        let distanceKm = viewModel.todaySummary.totalKgSaved / TransportMode.car.kgPerKm(in: viewModel.userProfile.resolvedRegion)
        return DisplayFormatting.distance(distanceKm, region: viewModel.userProfile.resolvedRegion)
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(value)
    }
}

struct HomeInsightRow: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.green)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
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
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
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
                HStack(spacing: 6) {
                    Text(entry.date.formatted(date: .omitted, time: .shortened))
                    Text("•")
                    Text(entry.source.rawValue)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Text(entry.isSavingEntry ? "Saved \(String(format: "%.2f", entry.absoluteKgCO2)) kg" : "\(String(format: "%.2f", entry.kgCO2)) kg")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(entry.isSavingEntry ? .green : .primary)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(entry.notes ?? entry.category.rawValue)
        .accessibilityValue(entry.isSavingEntry ? "Saved \(String(format: "%.2f", entry.absoluteKgCO2)) kilograms of carbon dioxide equivalent" : "Emitted \(String(format: "%.2f", entry.kgCO2)) kilograms of carbon dioxide equivalent")
    }
}

// MARK: - LogEntrySheet

struct LogEntrySheet: View {
    let viewModel: HomeViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedCategory: CarbonCategory = .transport
    @State private var selectedMode: TransportMode = .car
    @State private var distanceText: String = ""
    @State private var isRoundTrip: Bool = false
    @State private var selectedFoodType: CarbonCalculator.FoodType = .vegetables
    @State private var gramsText: String = ""
    @State private var selectedEnergySource: CarbonCalculator.EnergySource = .electricity
    @State private var kWhText: String = ""
    @State private var selectedProductCategory: CarbonCalculator.ProductCategory = .clothing
    @State private var spendText: String = ""
    @State private var manualKgText: String = ""
    @State private var notes: String = ""

    private let carbonCalculator = CarbonCalculator()

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
                                Text("Plan or capture a single action without leaving the home flow.")
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
                        .accessibilityElement(children: .combine)
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

                        LabeledContent(transportDistanceLabel) {
                            TextField("e.g. 14.5", text: $distanceText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 90)
                        }

                        Toggle("Include return trip", isOn: $isRoundTrip)

                        if isRoundTrip {
                            Text("Enter the one-way distance and we will double it for the trip back.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Label(
                            "\(selectedMode.rawValue) emits \(String(format: "%.3f", transportFactorPerDisplayedUnit)) kg per \(distanceUnitLabel)",
                            systemImage: selectedMode.icon
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                } else if selectedCategory == .food {
                    Section("Food Details") {
                        Picker("Food type", selection: $selectedFoodType) {
                            ForEach(CarbonCalculator.FoodType.allCases, id: \.self) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .pickerStyle(.navigationLink)

                        LabeledContent("Serving size (g)") {
                            TextField("e.g. 150", text: $gramsText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 90)
                        }

                        Label("This uses a simple per-serving estimate to help you log food impact consistently.", systemImage: "fork.knife")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else if selectedCategory == .energy {
                    Section("Energy Details") {
                        Picker("Energy source", selection: $selectedEnergySource) {
                            ForEach(CarbonCalculator.EnergySource.allCases, id: \.self) { source in
                                Text(source.rawValue).tag(source)
                            }
                        }
                        .pickerStyle(.segmented)

                        LabeledContent("Usage (kWh)") {
                            TextField("e.g. 4.5", text: $kWhText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 90)
                        }

                        Label("Use meter, bill, or appliance estimates when exact usage is not available.", systemImage: "bolt.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else if selectedCategory == .shopping {
                    Section("Shopping Details") {
                        Picker("Category", selection: $selectedProductCategory) {
                            ForEach(CarbonCalculator.ProductCategory.allCases, id: \.self) { category in
                                Text(category.rawValue).tag(category)
                            }
                        }
                        .pickerStyle(.navigationLink)

                        LabeledContent("Spend amount (\(currencyCode))") {
                            TextField("e.g. 45", text: $spendText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 90)
                        }

                        Label("Shopping estimates are broad and work best for quick comparisons across purchase types.", systemImage: "bag.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section("Manual Estimate") {
                        LabeledContent("CO₂ amount (kg)") {
                            TextField("e.g. 1.5", text: $manualKgText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 90)
                        }

                        Label("Use your best estimate for an activity that does not fit the guided calculators above.", systemImage: "chart.bar.doc.horizontal")
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
        switch selectedCategory {
        case .transport:
            return parsedDistanceKm != nil
        case .food:
            return Double(gramsText) != nil
        case .energy:
            return Double(kWhText) != nil
        case .shopping:
            return Double(spendText) != nil
        case .other:
            return Double(manualKgText) != nil
        }
    }

    private var estimatedKg: Double {
        switch selectedCategory {
        case .transport:
            return carbonCalculator.calculateTransport(
                mode: selectedMode,
                distanceKm: effectiveDistanceKm ?? 0,
                region: resolvedRegion
            )
        case .food:
            return carbonCalculator.calculateFood(
                type: selectedFoodType,
                grams: Double(gramsText) ?? 0,
                region: resolvedRegion
            )
        case .energy:
            let kWh = Double(kWhText) ?? 0
            switch selectedEnergySource {
            case .electricity:
                return carbonCalculator.calculateElectricity(kWh: kWh, region: resolvedRegion)
            case .gas:
                return carbonCalculator.calculateGas(kWh: kWh, region: resolvedRegion)
            }
        case .shopping:
            return carbonCalculator.calculateShopping(
                category: selectedProductCategory,
                spendAmount: Double(spendText) ?? 0,
                region: resolvedRegion
            )
        case .other:
            return Double(manualKgText) ?? 0
        }
    }

    private var impactDescription: String {
        switch selectedCategory {
        case .transport:
            return "Based on a \(isRoundTrip ? "round trip" : "one-way trip") of \(effectiveDistanceDisplayText) by \(selectedMode.rawValue.lowercased()). Use this while you plan or travel."
        case .food:
            return "Approximate food estimate based on serving size and category."
        case .energy:
            return "Approximate energy estimate based on \(selectedEnergySource.rawValue.lowercased()) usage."
        case .shopping:
            return "Broad shopping estimate based on spend and purchase category."
        case .other:
            return "This amount will be added to your \(selectedCategory.rawValue.lowercased()) footprint."
        }
    }

    private var resolvedRegion: CarbonRegion {
        viewModel.userProfile.resolvedRegion
    }

    private var distanceUnitLabel: String {
        DisplayFormatting.distanceUnitLabel(for: resolvedRegion)
    }

    private var parsedDistanceKm: Double? {
        DisplayFormatting.kilometers(from: distanceText, region: resolvedRegion)
    }

    private var effectiveDistanceKm: Double? {
        guard let parsedDistanceKm else { return nil }
        return isRoundTrip ? parsedDistanceKm * 2 : parsedDistanceKm
    }

    private var effectiveDistanceDisplayText: String {
        guard let effectiveDistanceKm else { return "0 \(distanceUnitLabel)" }
        return DisplayFormatting.distance(effectiveDistanceKm, region: resolvedRegion)
    }

    private var transportDistanceLabel: String {
        isRoundTrip ? "One-way distance (\(distanceUnitLabel))" : "Distance (\(distanceUnitLabel))"
    }

    private var transportFactorPerDisplayedUnit: Double {
        let kgPerKm = selectedMode.kgPerKm(in: resolvedRegion)
        switch resolvedRegion.distanceUnit {
        case .miles:
            return kgPerKm * 1.60934
        default:
            return kgPerKm
        }
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
        .accessibilityLabel(category.rawValue)
        .accessibilityValue(selectedCategory == category ? "Selected" : "Not selected")
        .accessibilityHint("Filters the calculator for \(category.rawValue.lowercased()) entries")
        .accessibilityAddTraits(selectedCategory == category ? .isSelected : [])
    }

    private var currencyCode: String {
        viewModel.userProfile.currencyCode
    }

    private func save() {
        switch selectedCategory {
        case .transport:
            guard let dist = effectiveDistanceKm else { return }
            viewModel.logTransportEntry(
                mode: selectedMode,
                distanceKm: dist,
                notes: notes.isEmpty ? transportAutoNote : notes
            )
        case .food:
            guard let grams = Double(gramsText) else { return }
            viewModel.logFoodEntry(type: selectedFoodType, grams: grams, notes: notes.isEmpty ? nil : notes)
        case .energy:
            guard let kWh = Double(kWhText) else { return }
            viewModel.logEnergyEntry(source: selectedEnergySource, kWh: kWh, notes: notes.isEmpty ? nil : notes)
        case .shopping:
            guard let spendAmount = Double(spendText) else { return }
            viewModel.logShoppingEntry(category: selectedProductCategory, spendAmount: spendAmount, notes: notes.isEmpty ? nil : notes)
        case .other:
            guard let kg = Double(manualKgText) else { return }
            viewModel.logCarbonEntry(
                category: selectedCategory,
                kgCO2: kg,
                notes: notes.isEmpty ? nil : notes
            )
        }
    }

    private var transportAutoNote: String? {
        guard let effectiveDistanceKm else { return nil }
        let tripType = isRoundTrip ? "round trip" : "one-way trip"
        return "\(selectedMode.rawValue) \(tripType) · \(DisplayFormatting.distance(effectiveDistanceKm, region: resolvedRegion))"
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
