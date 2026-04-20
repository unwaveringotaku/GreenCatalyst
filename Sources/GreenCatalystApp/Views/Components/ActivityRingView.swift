import SwiftUI

// MARK: - ActivityRingView
//
// A circular progress ring showing today's CO₂ vs target.
// Mirrors the style of Apple Fitness rings.

struct ActivityRingView: View {

    let progress: Double        // 0.0 – 1.0+ (clamped visually at 1.0)
    let kgCO2: Double
    let target: Double
    let size: CGFloat

    private var lineWidth: CGFloat { size * 0.12 }
    private var ringColor: Color {
        switch progress {
        case ..<0.5:  return .green
        case ..<0.75: return .yellow
        case ..<1.0:  return .orange
        default:      return .red
        }
    }

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(ringColor.opacity(0.15), lineWidth: lineWidth)

            // Progress ring
            Circle()
                .trim(from: 0, to: min(progress, 1.0))
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [ringColor, ringColor.opacity(0.7)]),
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.8, dampingFraction: 0.7), value: progress)

            // Overflow indicator (if over 100%)
            if progress > 1.0 {
                Circle()
                    .trim(from: 0, to: progress - 1.0)
                    .stroke(ringColor.opacity(0.4), style: StrokeStyle(lineWidth: lineWidth * 0.6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }

            // Centre label
            VStack(spacing: 2) {
                Text(String(format: "%.1f", kgCO2))
                    .font(.system(size: size * 0.22, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text("kg CO₂")
                    .font(.system(size: size * 0.10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
        .accessibilityHint("Shows progress against your carbon target")
    }

    private var accessibilityLabel: String {
        "Net carbon footprint"
    }
    private var accessibilityValue: String {
        if kgCO2 < 0 {
            return "\(String(format: "%.1f", abs(kgCO2))) kilograms below zero. Logged savings currently outweigh emissions."
        }

        let pct = max(0, Int(progress * 100))
        return "\(String(format: "%.1f", kgCO2)) kg CO₂ of \(String(format: "%.0f", target)) kg target, \(pct)%"
    }
}

// MARK: - Preview

#Preview {
    HStack(spacing: 20) {
        ActivityRingView(progress: 0.35, kgCO2: 2.8, target: 8.0, size: 100)
        ActivityRingView(progress: 0.72, kgCO2: 5.8, target: 8.0, size: 100)
        ActivityRingView(progress: 1.15, kgCO2: 9.2, target: 8.0, size: 100)
    }
    .padding()
}
