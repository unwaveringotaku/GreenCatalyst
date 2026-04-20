import SwiftUI

// MARK: - SiriView

/// Explains available Siri Shortcuts and lets the user add them to Siri.
struct SiriView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    siriHeroHeader
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                } header: {
                    EmptyView()
                }

                Section("Available Shortcuts") {
                    ForEach(ShortcutInfo.all) { shortcut in
                        ShortcutRow(shortcut: shortcut)
                    }
                }

                Section("How it works") {
                    VStack(alignment: .leading, spacing: 8) {
                        HowItWorksStep(number: "1", text: "Open the Shortcuts app from the button below")
                        HowItWorksStep(number: "2", text: "Find GreenCatalyst in App Shortcuts and add the shortcut you want")
                        HowItWorksStep(number: "3", text: "Use the suggested phrase or create your own custom trigger")
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    Button {
                        if let url = URL(string: "shortcuts://") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label("Open Shortcuts", systemImage: "waveform.circle.fill")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .accessibilityHint("Opens the Shortcuts app")
                }
            }
            .navigationTitle("Siri Shortcuts")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private var siriHeroHeader: some View {
        VStack(spacing: 12) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(
                    LinearGradient(colors: [.purple, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
            Text("Use GreenCatalyst with Siri")
                .font(.headline)
                .multilineTextAlignment(.center)
            Text("GreenCatalyst provides app shortcuts for quick voice logging and a spoken carbon score. Shortcuts are added and managed in the Shortcuts app.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - ShortcutInfo

struct ShortcutInfo: Identifiable {
    let id: UUID = UUID()
    let title: String
    let subtitle: String
    let examplePhrase: String
    let icon: String
    let tint: Color

    static let all: [ShortcutInfo] = [
        ShortcutInfo(
            title: "Log Activity",
            subtitle: "Record a commute, meal, or energy event",
            examplePhrase: "\"Log my bike commute\"",
            icon: "plus.circle.fill",
            tint: .green
        ),
        ShortcutInfo(
            title: "Get Carbon Score",
            subtitle: "Hear today's total CO₂ in kg",
            examplePhrase: "\"What's my carbon score?\"",
            icon: "chart.line.uptrend.xyaxis.circle.fill",
            tint: .blue
        ),
    ]
}

// MARK: - ShortcutRow

struct ShortcutRow: View {
    let shortcut: ShortcutInfo

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: shortcut.icon)
                .font(.title2)
                .foregroundStyle(shortcut.tint)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 3) {
                Text(shortcut.title).font(.headline)
                Text(shortcut.subtitle).font(.subheadline).foregroundStyle(.secondary)
                Text(shortcut.examplePhrase)
                    .font(.caption)
                    .foregroundStyle(.purple)
                    .italic()
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - HowItWorksStep

struct HowItWorksStep: View {
    let number: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.headline.bold())
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(Color.purple)
                .clipShape(Circle())
            Text(text)
                .font(.subheadline)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    SiriView()
}
