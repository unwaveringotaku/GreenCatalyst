import SwiftUI

// MARK: - HabitRowView
//
// A single row in the Habits list, with completion button, streak badge,
// and contextual menu for edit / delete.

struct HabitRowView: View {

    let habit: Habit
    let onComplete: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var bouncing: Bool = false

    var body: some View {
        HStack(spacing: 14) {

            // Completion button
            completionButton

            // Habit info
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(habit.name)
                        .font(.subheadline.bold())
                        .strikethrough(habit.isCompletedToday)
                        .foregroundStyle(habit.isCompletedToday ? .secondary : .primary)

                    if habit.isStreakAtRisk {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }

                HStack(spacing: 8) {
                    // Category chip
                    Label(habit.category.rawValue, systemImage: habit.category.icon)
                        .font(.caption2.bold())
                        .foregroundStyle(Color(hex: habit.category.color))

                    // Frequency
                    Text("·  \(habit.frequency.rawValue)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                // Savings
                HStack(spacing: 6) {
                    Label(String(format: "%.1f kg CO₂", habit.co2PerAction), systemImage: "leaf.fill")
                        .font(.caption2)
                        .foregroundStyle(.green)
                    if habit.costPerAction > 0 {
                        Label(String(format: "£%.2f", habit.costPerAction), systemImage: "sterlingsign.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                    }
                }
            }

            Spacer()

            // Streak badge
            streakBadge
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .contextMenu {
            Button("Edit", systemImage: "pencil", action: onEdit)
            Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            if !habit.isCompletedToday {
                Button("Done", systemImage: "checkmark") {
                    withAnimation(.spring(response: 0.3)) { bouncing = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { bouncing = false }
                    onComplete()
                }
                .tint(.green)
            }
        }
    }

    // MARK: - Completion Button

    private var completionButton: some View {
        Button(action: {
            guard !habit.isCompletedToday else { return }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.5)) { bouncing = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                withAnimation { bouncing = false }
            }
            onComplete()
        }) {
            ZStack {
                Circle()
                    .fill(habit.isCompletedToday
                          ? Color(hex: habit.colorHex)
                          : Color(.tertiarySystemFill))
                    .frame(width: 40, height: 40)

                if habit.isCompletedToday {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                } else {
                    Image(systemName: habit.icon)
                        .font(.system(size: 16))
                        .foregroundStyle(Color(hex: habit.colorHex))
                }
            }
            .scaleEffect(bouncing ? 1.3 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(habit.isCompletedToday)
    }

    // MARK: - Streak Badge

    private var streakBadge: some View {
        VStack(spacing: 2) {
            HStack(spacing: 2) {
                Image(systemName: "flame.fill")
                    .font(.caption)
                    .foregroundStyle(habit.streakCount > 0 ? .orange : .secondary)
                Text("\(habit.streakCount)")
                    .font(.subheadline.bold().monospacedDigit())
                    .foregroundStyle(habit.streakCount > 0 ? .orange : .secondary)
            }
            Text("streak")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(width: 50)
    }
}

#Preview {
    VStack(spacing: 12) {
        ForEach(Habit.defaults) { habit in
            HabitRowView(
                habit: habit,
                onComplete: {},
                onEdit: {},
                onDelete: {}
            )
        }
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
