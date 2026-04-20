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
    @State private var isCheckingOnboarding: Bool = true

    var body: some View {
        Group {
            if isCheckingOnboarding {
                onboardingLoadingView
            } else {
                mainTabView
            }
        }
        .task {
            await checkOnboardingState()
        }
        .onOpenURL { url in
            handleDeepLink(url)
        }
    }

    private var mainTabView: some View {
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
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingFlowView(isPresented: $showOnboarding)
        }
    }

    private var onboardingLoadingView: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            ProgressView("Loading GreenCatalyst...")
                .progressViewStyle(.circular)
                .accessibilityLabel("Loading GreenCatalyst")
        }
    }

    // MARK: - Onboarding Check

    private func checkOnboardingState() async {
        let profile = try? await DataStore.shared.fetchUserProfile()
        showOnboarding = !(profile?.hasCompletedOnboarding ?? false)
        isCheckingOnboarding = false
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

// MARK: - OnboardingFlowView

struct OnboardingFlowView: View {
    @Binding var isPresented: Bool
    @State private var phase: OnboardingPhase = .carousel

    enum OnboardingPhase {
        case carousel
        case userInfo
    }

    var body: some View {
        switch phase {
        case .carousel:
            OnboardingCarouselView {
                withAnimation { phase = .userInfo }
            }
        case .userInfo:
            UserInfoOnboardingView(isPresented: $isPresented)
        }
    }
}

// MARK: - OnboardingView

struct OnboardingCarouselView: View {
    let onFinish: () -> Void
    @State private var currentPage: Int = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "leaf.circle.fill",
            title: "See What Choices Mean",
            body: "Track transport, food, energy, and shopping with clear calculators, then translate the totals into habits, trips, and money saved.",
            tint: .green
        ),
        OnboardingPage(
            icon: "bell.badge.fill",
            title: "Plan Around Your Day",
            body: "Get prompts for commutes, meals, and purchases that are easier to act on while the task is still in front of you.",
            tint: .orange
        ),
        OnboardingPage(
            icon: "flame.fill",
            title: "Build Wins You Can Feel",
            body: "Use habits, streaks, and savings to make progress more concrete than a single carbon number.",
            tint: .red
        ),
        OnboardingPage(
            icon: "person.2.fill",
            title: "Share Progress Easily",
            body: "Export or share your wins with friends while the product grows toward deeper schedule-aware and social features.",
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
                        .accessibilityHint("Moves to the next onboarding page")

                        Button("Skip") { finish() }
                            .foregroundStyle(.secondary)
                            .accessibilityHint("Skips onboarding details")
                    } else {
                        Button("Get Started 🌿") { finish() }
                            .buttonStyle(.borderedProminent)
                            .tint(.green)
                            .frame(maxWidth: .infinity)
                            .accessibilityHint("Finishes onboarding")
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
            .navigationBarHidden(true)
        }
    }

    private func finish() {
        onFinish()
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
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    ContentView()
}
