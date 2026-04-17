import SwiftUI

// MARK: - WatchHomeView

struct WatchHomeView: View {

    @State private var store = WatchDataStore.shared
    @State private var showNudge = false

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {

                // MARK: CO₂ Ring
                carbonRing

                // MARK: Streak
                streakRow

                // MARK: Top Nudge
                if let nudge = store.topNudgeTitle {
                    nudgeButton(title: nudge)
                }

                // MARK: Sync Button
                Button {
                    store.sendUpdateToPhone()
                } label: {
                    Label("Sync", systemImage: "arrow.2.circlepath")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("GreenCatalyst")
    }

    // MARK: - CO₂ Ring

    private var carbonRing: some View {
        ZStack {
            // Background track
            Circle()
                .stroke(ringColor.opacity(0.2), lineWidth: 8)
                .frame(width: 90, height: 90)

            // Progress arc
            Circle()
                .trim(from: 0, to: store.progress)
                .stroke(
                    AngularGradient(
                        colors: [ringColor, ringColor.opacity(0.6)],
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: 90, height: 90)
                .animation(.spring(response: 0.8), value: store.progress)

            // Centre
            VStack(spacing: 1) {
                Text(String(format: "%.1f", store.kgCO2Today))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text("kg CO₂")
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Streak

    private var streakRow: some View {
        HStack {
            Image(systemName: "flame.fill")
                .foregroundStyle(.orange)
            Text("\(store.topStreak) day streak")
                .font(.caption.bold())
            Spacer()
            Image(systemName: store.isUnderTarget ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundStyle(store.isUnderTarget ? .green : .orange)
        }
        .padding(8)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Nudge

    private func nudgeButton(title: String) -> some View {
        Button {
            showNudge = true
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "bell.badge.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                    Text("Nudge")
                        .font(.caption2.bold())
                        .foregroundStyle(.orange)
                }
                Text(title)
                    .font(.caption)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                if store.topNudgeCO2 > 0 {
                    Label(String(format: "Saves %.1f kg", store.topNudgeCO2), systemImage: "leaf.fill")
                        .font(.caption2)
                        .foregroundStyle(.green)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background(Color.orange.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showNudge) {
            NudgeDetailView(title: title, co2Saving: store.topNudgeCO2)
        }
    }

    // MARK: - Helpers

    private var ringColor: Color {
        switch store.progress {
        case ..<0.5:  return .green
        case ..<0.75: return .yellow
        case ..<1.0:  return .orange
        default:      return .red
        }
    }
}

// MARK: - NudgeDetailView (Watch Sheet)

struct NudgeDetailView: View {
    let title: String
    let co2Saving: Double
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "bell.badge.fill")
                .font(.title3)
                .foregroundStyle(.orange)

            Text(title)
                .font(.caption.bold())
                .multilineTextAlignment(.center)

            if co2Saving > 0 {
                Label(String(format: "Saves %.1f kg CO₂", co2Saving), systemImage: "leaf.fill")
                    .font(.caption2)
                    .foregroundStyle(.green)
            }

            Button("Done ✅") { dismiss() }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .font(.caption.bold())
        }
        .padding()
    }
}

#Preview {
    WatchHomeView()
}
