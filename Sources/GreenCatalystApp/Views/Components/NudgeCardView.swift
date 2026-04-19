import SwiftUI

// MARK: - NudgeCardView
//
// A swipeable action card shown on the Home tab.
// Swipe right → complete. Swipe left → dismiss.

struct NudgeCardView: View {

    let nudge: Nudge
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

                priorityBadge
            }

            Text(nudge.nudgeDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)

            // Savings pills
            HStack(spacing: 8) {
                SavingPill(icon: "leaf.fill", value: String(format: "%.1f kg CO₂", nudge.co2Saving), tint: .green)
                if nudge.costSaving > 0 {
                    SavingPill(icon: "sterlingsign.circle.fill", value: String(format: "£%.2f", nudge.costSaving), tint: .blue)
                }
                Spacer()

                // Quick-action buttons
                Button(action: handleDismiss) {
                    Image(systemName: "xmark").font(.caption.bold())
                }
                .buttonStyle(.bordered)
                .tint(.gray)
                .disabled(isDone || isGone)

                Button(action: handleComplete) {
                    Label("Done", systemImage: "checkmark")
                        .font(.caption.bold())
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(isDone || isGone)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 6, y: 3)
    }

    // MARK: - Helpers

    private func actionLabel(icon: String, text: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.title2).foregroundStyle(color)
            Text(text).font(.caption.bold()).foregroundStyle(color)
        }
        .frame(width: 60)
    }

    private var categoryGradient: LinearGradient {
        let base = Color(hex: nudge.category.color)
        return LinearGradient(colors: [base, base.opacity(0.75)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private var priorityBadge: some View {
        Group {
            switch nudge.priority {
            case .high:
                Text("HIGH")
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundStyle(.red)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.red.opacity(0.12))
                    .clipShape(Capsule())
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
    }
}

#Preview {
    VStack(spacing: 16) {
        ForEach(Nudge.sampleNudges.prefix(2)) { nudge in
            NudgeCardView(nudge: nudge, onComplete: {}, onDismiss: {})
        }
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
