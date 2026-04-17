import SwiftUI

// MARK: - Tab

enum AppTab: String, CaseIterable {
    case home    = "Home"
    case impact  = "Impact"
    case habits  = "Habits"
    case siri    = "Shortcuts"

    var icon: String {
        switch self {
        case .home:   return "leaf.circle.fill"
        case .impact: return "chart.pie.fill"
        case .habits: return "flame.fill"
        case .siri:   return "waveform.circle.fill"
        }
    }
}

// MARK: - ContentView

struct ContentView: View {

    @State private var selectedTab: AppTab = .home
    @State private var showOnboarding: Bool = false

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem { Label(AppTab.home.rawValue,    systemImage: AppTab.home.icon)    }
                .tag(AppTab.home)

            ImpactView()
                .tabItem { Label(AppTab.impact.rawValue,  systemImage: AppTab.impact.icon)  }
                .tag(AppTab.impact)

            HabitsView()
                .tabItem { Label(AppTab.habits.rawValue,  systemImage: AppTab.habits.icon)  }
                .tag(AppTab.habits)

            SiriView()
                .tabItem { Label(AppTab.siri.rawValue,    systemImage: AppTab.siri.icon)    }
                .tag(AppTab.siri)
        }
        .tint(.green)
        .sheet(isPresented: $showOnboarding) {
            OnboardingView(isPresented: $showOnboarding)
        }
        .task {
            // Show onboarding if first launch
            let defaults = UserDefaults.standard
            if !defaults.bool(forKey: "hasSeenOnboarding") {
                showOnboarding = true
            }
        }
        .onOpenURL { url in
            handleDeepLink(url)
        }
    }

    // MARK: - Deep Link

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "greencatalyst" else { return }
        switch url.host {
        case "home":      selectedTab = .home
        case "impact":    selectedTab = .impact
        case "habits":    selectedTab = .habits
        case "shortcuts": selectedTab = .siri
        default:          break
        }
    }
}

// MARK: - OnboardingView

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @State private var currentPage: Int = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "leaf.circle.fill",
            title: "Track Your Footprint",
            body: "Log transport, food, energy, and shopping to understand your personal carbon impact.",
            tint: .green
        ),
        OnboardingPage(
            icon: "bell.badge.fill",
            title: "Smart Nudges",
            body: "Receive personalised, time-sensitive action suggestions that save CO₂ and money.",
            tint: .orange
        ),
        OnboardingPage(
            icon: "flame.fill",
            title: "Build Streaks",
            body: "Form sustainable habits and build daily streaks to make green living effortless.",
            tint: .red
        ),
        OnboardingPage(
            icon: "heart.fill",
            title: "HealthKit + Siri",
            body: "Automatically detect your commute from HealthKit and log activities with your voice.",
            tint: .pink
        ),
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        OnboardingPageView(page: page)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))

                VStack(spacing: 12) {
                    if currentPage < pages.count - 1 {
                        Button("Next") {
                            withAnimation { currentPage += 1 }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                        .frame(maxWidth: .infinity)

                        Button("Skip") { finish() }
                            .foregroundStyle(.secondary)
                    } else {
                        Button("Get Started 🌿") { finish() }
                            .buttonStyle(.borderedProminent)
                            .tint(.green)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
            .navigationBarHidden(true)
        }
    }

    private func finish() {
        UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
        Task {
            await NotificationManager.shared.requestAuthorization()
            await HealthKitManager.shared.requestAuthorization()
        }
        isPresented = false
    }
}

// MARK: - OnboardingPage + View

struct OnboardingPage {
    let icon: String
    let title: String
    let body: String
    let tint: Color
}

struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: page.icon)
                .font(.system(size: 90))
                .foregroundStyle(page.tint)
                .symbolEffect(.pulse)

            VStack(spacing: 12) {
                Text(page.title)
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                Text(page.body)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            Spacer()
        }
        .padding(.horizontal, 24)
    }
}

#Preview {
    ContentView()
}
