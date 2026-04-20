import SwiftUI

// MARK: - HabitsView

struct HabitsView: View {

    @State private var viewModel = HabitsViewModel()
    @State private var showAddSheet = false
    @State private var habitToEdit: Habit? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    // Stats header
                    statsHeader

                    // Category filter
                    categoryFilter

                    // Habits list
                    habitsGrid

                    Spacer(minLength: 80)
                }
                .padding(.horizontal)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Habits")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAddSheet = true } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.green)
                    }
                    .accessibilityLabel("Add habit")
                }
            }
            .sheet(isPresented: $showAddSheet, onDismiss: { Task { await viewModel.loadHabits() } }) {
                AddHabitSheet(viewModel: viewModel)
            }
            .sheet(item: $habitToEdit, onDismiss: { Task { await viewModel.loadHabits() } }) { habit in
                EditHabitSheet(habit: habit, viewModel: viewModel)
            }
            .task { viewModel.onAppear() }
            .onReceive(NotificationCenter.default.publisher(for: .habitDataDidChange)) { _ in
                Task { await viewModel.loadHabits() }
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    // MARK: - Stats Header

    private var statsHeader: some View {
        HStack(spacing: 0) {
            StatCell(
                value: "\(viewModel.totalStreakDays)",
                label: "Total Streak Days",
                icon: "flame.fill",
                tint: .orange
            )
            Divider().frame(height: 50)
            StatCell(
                value: String(format: "%.1f kg", viewModel.totalCO2Saved),
                label: "CO₂ Saved",
                icon: "leaf.fill",
                tint: .green
            )
            Divider().frame(height: 50)
            StatCell(
                value: DisplayFormatting.currency(viewModel.totalCostSaved, currencyCode: viewModel.currencyCode),
                label: "Money Saved",
                icon: "banknote.fill",
                tint: .blue
            )
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .contain)
    }

    // MARK: - Category Filter

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(
                    label: "All",
                    icon: "square.grid.2x2.fill",
                    isSelected: viewModel.selectedCategory == nil,
                    tint: .primary
                ) {
                    viewModel.selectedCategory = nil
                }

                ForEach(CarbonCategory.allCases) { cat in
                    FilterChip(
                        label: cat.rawValue,
                        icon: cat.icon,
                        isSelected: viewModel.selectedCategory == cat,
                        tint: Color(hex: cat.color)
                    ) {
                        viewModel.selectedCategory = (viewModel.selectedCategory == cat) ? nil : cat
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Habits Grid

    @ViewBuilder
    private var habitsGrid: some View {
        if viewModel.activeHabits.isEmpty {
            EmptyHabitsView { showAddSheet = true }
        } else {
            VStack(spacing: 12) {
                ForEach(viewModel.activeHabits) { habit in
                    HabitRowView(
                        habit: habit,
                        onComplete: { viewModel.completeHabit(habit) },
                        onEdit: { habitToEdit = habit },
                        onDelete: { viewModel.deleteHabit(habit) }
                    )
                }
            }
        }
    }
}

// MARK: - StatCell

struct StatCell: View {
    let value: String
    let label: String
    let icon: String
    let tint: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon).foregroundStyle(tint).font(.title3)
            Text(value).font(.headline.bold())
            Text(label).font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(value)
    }
}

// MARK: - FilterChip

struct FilterChip: View {
    let label: String
    let icon: String
    let isSelected: Bool
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.caption)
                Text(label).font(.caption.bold())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? tint : Color(.tertiarySystemFill))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
        .accessibilityLabel(label)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - EmptyHabitsView

struct EmptyHabitsView: View {
    let onAdd: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "leaf.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.green.opacity(0.6))
            Text("No habits yet")
                .font(.title3.bold())
            Text("Add your first sustainable habit and start building your streak.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Add Habit", action: onAdd)
                .buttonStyle(.borderedProminent)
                .tint(.green)
        }
        .padding(40)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - AddHabitSheet

struct AddHabitSheet: View {
    let viewModel: HabitsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var description: String = ""
    @State private var category: CarbonCategory = .transport
    @State private var frequency: HabitFrequency = .daily
    @State private var co2PerAction: String = "1.0"
    @State private var costPerAction: String = "0.0"
    @State private var icon: String = "leaf.fill"
    @State private var reminderEnabled: Bool = false
    @State private var reminderTime: Date = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: .now) ?? .now

    private let availableIcons = ["bicycle", "leaf.fill", "drop.fill", "bag.fill", "car.fill",
                                   "tram.fill", "fork.knife", "sun.max.fill", "wind", "arrow.3.trianglepath",
                                   "figure.walk", "bolt.fill", "trash.fill", "cart.fill"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Habit name", text: $name)
                    TextField("Description (optional)", text: $description)
                }

                Section("Category & Frequency") {
                    Picker("Category", selection: $category) {
                        ForEach(CarbonCategory.allCases) { cat in
                            Label(cat.rawValue, systemImage: cat.icon).tag(cat)
                        }
                    }
                    Picker("Frequency", selection: $frequency) {
                        ForEach(HabitFrequency.allCases, id: \.self) { freq in
                            Text(freq.rawValue).tag(freq)
                        }
                    }
                }

                Section("Impact per action") {
                    HStack {
                        Text("CO₂ saved (kg)")
                        Spacer()
                        TextField("1.0", text: $co2PerAction)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    HStack {
                        Text("Money saved")
                        Spacer()
                        TextField("0.0", text: $costPerAction)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    .accessibilityLabel("Money saved per action in \(viewModel.currencyCode)")
                }

                Section("Icon") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(availableIcons, id: \.self) { sf in
                                Button {
                                    icon = sf
                                } label: {
                                    Image(systemName: sf)
                                        .font(.title2)
                                        .foregroundStyle(icon == sf ? .white : .primary)
                                        .padding(10)
                                        .background(icon == sf ? Color.green : Color(.tertiarySystemFill))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(sf)
                                .accessibilityValue(icon == sf ? "Selected" : "Not selected")
                                .accessibilityAddTraits(icon == sf ? .isSelected : [])
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("Reminder") {
                    Toggle("Enable daily reminder", isOn: $reminderEnabled)
                    if reminderEnabled {
                        DatePicker("Time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                    }
                }
            }
            .navigationTitle("New Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let habit = Habit(
                            name: name,
                            habitDescription: description,
                            category: category,
                            frequency: frequency,
                            co2PerAction: Double(co2PerAction) ?? 1.0,
                            costPerAction: Double(costPerAction) ?? 0.0,
                            icon: icon,
                            reminderTime: reminderEnabled ? reminderTime : nil
                        )
                        viewModel.addHabit(habit)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

// MARK: - EditHabitSheet

struct EditHabitSheet: View {
    let habit: Habit
    let viewModel: HabitsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var reminderEnabled: Bool
    @State private var reminderTime: Date

    init(habit: Habit, viewModel: HabitsViewModel) {
        self.habit = habit
        self.viewModel = viewModel
        _reminderEnabled = State(initialValue: habit.reminderTime != nil)
        _reminderTime = State(initialValue: habit.reminderTime ?? .now)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Info") {
                    LabeledContent("Name", value: habit.name)
                    LabeledContent("Category", value: habit.category.rawValue)
                    LabeledContent("Streak", value: "\(habit.streakCount) days")
                    LabeledContent("CO₂ saved total", value: String(format: "%.1f kg", habit.totalCO2Saved))
                    LabeledContent(
                        "Money saved total",
                        value: DisplayFormatting.currency(habit.totalCostSaved, currencyCode: viewModel.currencyCode)
                    )
                }

                Section("Reminder") {
                    Toggle("Enable", isOn: $reminderEnabled)
                    if reminderEnabled {
                        DatePicker("Time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                    }
                }

                Section {
                    Button("Delete Habit", role: .destructive) {
                        viewModel.deleteHabit(habit)
                        dismiss()
                    }
                }
            }
            .navigationTitle("Edit Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            try? await viewModel.updateReminder(for: habit, time: reminderEnabled ? reminderTime : nil)
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    HabitsView()
}
