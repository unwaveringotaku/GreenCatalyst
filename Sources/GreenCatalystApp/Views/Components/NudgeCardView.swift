import SwiftUI

// MARK: - NudgeCardView
//
// A swipeable action card shown on the Home tab.
// Swipe right → complete. Swipe left → dismiss.

struct NudgeCardView: View {

    let nudge: Nudge
    let region: CarbonRegion
    let onComplete: () -> Void
    let onDismiss: () -> Void

    @State private var dragOffset: CGFloat = 0
    @State private var isDone: Bool = false
    @State private var isGone: Bool = false

    private let swipeThreshold: CGFloat = 80

    var body: some View {
        ZStack {
            // Background actions (revealed on swipe)
            HStack {
                // Complete action (swipe right)
                actionLabel(icon: "checkmark.circle.fill", text: "Done", color: .green)
                Spacer()
                // Dismiss action (swipe left)
                actionLabel(icon: "xmark.circle.fill", text: "Skip", color: .gray)
            }
            .padding(.horizontal)
            .accessibilityHidden(true)

            // Card
            cardContent
                .offset(x: dragOffset)
                .gesture(
                    DragGesture(minimumDistance: 10, coordinateSpace: .local)
                        .onChanged { value in
                            dragOffset = value.translation.width
                        }
                        .onEnded { value in
                            let width = value.translation.width
                            if width > swipeThreshold {
                                handleComplete()
                            } else if width < -swipeThreshold {
                                handleDismiss()
                            } else {
                                withAnimation(.spring()) { dragOffset = 0 }
                            }
                        }
                )
        }
        .opacity(isDone || isGone ? 0 : 1)
        .animation(.easeOut(duration: 0.2), value: isDone || isGone)
    }

    // MARK: - Card Content

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                // Icon
                Image(systemName: nudge.icon)
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(categoryGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text(nudge.title)
                        .font(.subheadline.bold())
                        .lineLimit(2)
                    if let remaining = nudge.timeRemainingText {
                        Text(remaining)
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    if let stageLabel = presentation.stageLabel {
                        badge(text: stageLabel, tint: .orange)
                    }

                    priorityBadge
                }
            }

            Text(nudge.nudgeDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)

            if !presentation.detailLabels.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(presentation.detailLabels, id: \.self) { label in
                            badge(text: label, tint: .gray)
                        }
                    }
                }
            }

            // Savings pills
            HStack(spacing: 8) {
                SavingPill(icon: "leaf.fill", value: String(format: "%.1f kg CO₂", nudge.co2Saving), tint: .green)
                if nudge.costSaving > 0 {
                    SavingPill(
                        icon: "banknote.fill",
                        value: DisplayFormatting.currency(nudge.costSaving, currencyCode: region.currencyCode),
                        tint: .blue
                    )
                }
                Spacer()

                // Quick-action buttons
                Button(action: handleDismiss) {
                    Image(systemName: "xmark").font(.caption.bold())
                }
                .buttonStyle(.bordered)
                .tint(.gray)
                .disabled(isDone || isGone)
                .accessibilityLabel("Skip suggestion")
                .accessibilityHint("Dismisses this suggestion")

                Button(action: handleComplete) {
                    Label("Done", systemImage: "checkmark")
                        .font(.caption.bold())
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(isDone || isGone)
                .accessibilityLabel("Complete suggestion")
                .accessibilityHint("Logs this suggestion as completed")
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 6, y: 3)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(nudge.title)
        .accessibilityValue(cardAccessibilityValue)
        .accessibilityHint("Use the Done or Skip buttons to act on this suggestion")
        .accessibilityAction(named: "Done") { handleComplete() }
        .accessibilityAction(named: "Skip") { handleDismiss() }
    }

    // MARK: - Helpers

    private var presentation: NudgePresentation {
        NudgePresentation(nudge: nudge, region: region)
    }

    private func actionLabel(icon: String, text: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.title2).foregroundStyle(color)
            Text(text).font(.caption.bold()).foregroundStyle(color)
        }
        .frame(width: 60)
    }

    private func badge(text: String, tint: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(tint == .gray ? .secondary : tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background((tint == .gray ? Color(.tertiarySystemFill) : tint.opacity(0.12)))
            .clipShape(Capsule())
    }

    private var categoryGradient: LinearGradient {
        let base = Color(hex: nudge.category.color)
        return LinearGradient(colors: [base, base.opacity(0.75)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private var priorityBadge: some View {
        Group {
            switch nudge.priority {
            case .high:
                badge(text: "High impact", tint: .red)
            case .medium:
                EmptyView()
            case .low:
                EmptyView()
            }
        }
    }

    private func handleComplete() {
        guard !isDone && !isGone else { return }
        withAnimation(.spring()) { dragOffset = 400 }
        isDone = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { onComplete() }
    }

    private func handleDismiss() {
        guard !isDone && !isGone else { return }
        withAnimation(.spring()) { dragOffset = -400 }
        isGone = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { onDismiss() }
    }
}

// MARK: - SavingPill

struct SavingPill: View {
    let icon: String
    let value: String
    let tint: Color

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 10))
            Text(value).font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(tint.opacity(0.12))
        .clipShape(Capsule())
        .accessibilityElement(children: .combine)
    }
}

private extension NudgeCardView {
    var cardAccessibilityValue: String {
        var parts = [nudge.nudgeDescription, "Saves \(String(format: "%.1f", nudge.co2Saving)) kilograms of carbon dioxide equivalent"]

        if nudge.costSaving > 0 {
            parts.append("\(DisplayFormatting.currency(nudge.costSaving, currencyCode: region.currencyCode)) saved")
        }

        if let remaining = nudge.timeRemainingText {
            parts.append(remaining)
        }

        parts.append(contentsOf: presentation.detailLabels)

        if let stageLabel = presentation.stageLabel {
            parts.append(stageLabel)
        }

        if nudge.priority == .high {
            parts.append("High priority")
        }

        return parts.joined(separator: ", ")
    }
}

private struct NudgePresentation {
    let stageLabel: String?
    let detailLabels: [String]

    init(nudge: Nudge, region: CarbonRegion) {
        let title = nudge.title.lowercased()

        if title.contains("work trip") {
            stageLabel = "Before you leave"
            detailLabels = [
                "Commute",
                DisplayFormatting.distance(22.5, region: region),
                "Round trip",
            ]
        } else if title.contains("lunch") {
            stageLabel = "Before you order"
            detailLabels = [
                "Lunch window",
                "Meal swap",
            ]
        } else if title.contains("desk setup") {
            stageLabel = "Helpful right now"
            detailLabels = [
                "While working",
                "In progress",
            ]
        } else if title.contains("resale") || title.contains("buying new") {
            stageLabel = "Before you buy"
            detailLabels = [
                "Weekend errand",
                "Purchase check",
            ]
        } else {
            stageLabel = nil
            detailLabels = []
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        ForEach(Nudge.sampleNudges.prefix(2)) { nudge in
            NudgeCardView(nudge: nudge, region: .northAmerica, onComplete: {}, onDismiss: {})
        }
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
