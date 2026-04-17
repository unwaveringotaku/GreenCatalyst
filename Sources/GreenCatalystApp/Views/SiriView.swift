import SwiftUI
import AppIntents

// MARK: - SiriView

/// Explains available Siri Shortcuts and lets the user add them to Siri.
struct SiriView: View {

    @State private var showAddShortcut = false
    @State private var selectedIntent: ShortcutInfo? = nil

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
                        ShortcutRow(shortcut: shortcut) {
                            selectedIntent = shortcut
                        }
                    }
                }

                Section("How it works") {
                    VStack(alignment: .leading, spacing: 8) {
                        HowItWorksStep(number: "1", text: "Tap \"Add to Siri\" on any shortcut above")
                        HowItWorksStep(number: "2", text: "Record your custom phrase (or use ours)")
                        HowItWorksStep(number: "3", text: "Say it to Siri anywhere — Lock Screen, AirPods, Apple Watch")
                    }
                    .padding(.vertical, 4)
                }

                Section("App Intents") {
                    Label("Log Activity — records a trip or food choice", systemImage: "plus.circle")
                    Label("Get Carbon Score — returns today's CO₂ number", systemImage: "chart.line.uptrend.xyaxis")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            .navigationTitle("Siri Shortcuts")
            .navigationBarTitleDisplayMode(.large)
            .sheet(item: $selectedIntent) { info in
                AddToSiriSheet(shortcutInfo: info)
            }
        }
    }

    private var siriHeroHeader: some View {
        VStack(spacing: 12) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(
                    LinearGradient(colors: [.purple, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
            Text("Control GreenCatalyst with your voice")
                .font(.headline)
                .multilineTextAlignment(.center)
            Text("Add shortcuts to Siri so you can log activities and check your score hands-free.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
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
    let onAdd: () -> Void

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

            Spacer()

            Button("Add", action: onAdd)
                .font(.caption.bold())
                .buttonStyle(.bordered)
                .tint(shortcut.tint)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - AddToSiriSheet

struct AddToSiriSheet: View {
    let shortcutInfo: ShortcutInfo
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: shortcutInfo.icon)
                    .font(.system(size: 72))
                    .foregroundStyle(shortcutInfo.tint)
                    .padding(.top, 40)

                Text(shortcutInfo.title)
                    .font(.title.bold())

                Text(shortcutInfo.subtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                VStack(spacing: 8) {
                    Text("Example phrase:")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Text(shortcutInfo.examplePhrase)
                        .font(.title3.bold())
                        .foregroundStyle(.purple)
                        .padding()
                        .background(Color.purple.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // In a real app, use SiriTipView from AppIntents here.
                // SiriTipView is not directly instantiatable without an intent instance,
                // so we show a custom button that deep-links to Shortcuts.
                Button {
                    if let url = URL(string: "shortcuts://") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Label("Open Shortcuts App", systemImage: "waveform.circle.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.purple)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
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
    }
}

#Preview {
    SiriView()
}
