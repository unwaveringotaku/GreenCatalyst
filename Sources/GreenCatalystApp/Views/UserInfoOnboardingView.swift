import SwiftUI

// MARK: - UserInfoOnboardingView

struct UserInfoOnboardingView: View {

    @Binding var isPresented: Bool
    @State private var step: Int = 0
    @FocusState private var focusedField: Field?

    // Form state
    @State private var userName: String = ""
    @State private var dietaryPreference: DietaryPreference = .omnivore
    @State private var regionPreference: CarbonRegionPreference = .automatic
    @State private var goalPercent: Double = 85
    @State private var isSaving: Bool = false

    private enum Field {
        case userName
    }

    var body: some View {
        VStack(spacing: 0) {
            // Step indicator
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    ForEach(0..<3) { i in
                        Capsule()
                            .fill(i <= step ? Color.green : Color.gray.opacity(0.3))
                            .frame(height: 4)
                    }
                }

                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(stepTitles[step])
                            .font(.headline)
                        Text(stepSubtitles[step])
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if step > 0 {
                        Button("Back") {
                            withAnimation { step -= 1 }
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.green)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .accessibilityLabel("Onboarding step \(step + 1) of 3")

            TabView(selection: $step) {
                appleSignInStep.tag(0)
                profileStep.tag(1)
                goalStep.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: step)
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Step 0: Intro

    private var appleSignInStep: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "leaf.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green)

            VStack(spacing: 8) {
                Text("Make this useful in real life")
                    .font(.title.bold())
                Text("GreenCatalyst v1.0.2 is designed to explain your impact in plain language: money, trips, habits, and daily progress.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            VStack(alignment: .leading, spacing: 12) {
                onboardingPoint(icon: "banknote.fill", text: "See where lower-impact choices can also save money, not just carbon.")
                onboardingPoint(icon: "figure.walk.motion", text: "Get clearer prompts for commutes, meals, and in-progress tasks.")
                onboardingPoint(icon: "chart.bar.fill", text: "Translate totals into everyday meaning so the numbers are easier to act on.")
            }
            .padding(20)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .padding(.horizontal, 24)

            Button {
                withAnimation { step = 1 }
            } label: {
                Text("Continue")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .padding(.horizontal, 24)
            .accessibilityHint("Moves to profile details")

            Spacer()
        }
    }

    // MARK: - Step 1: Profile Details

    private var profileStep: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.green)

            Text("About You")
                .font(.title.bold())

            VStack(spacing: 16) {
                TextField("Your name", text: $userName)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.name)
                    .submitLabel(.done)
                    .focused($focusedField, equals: .userName)
                    .padding(.horizontal, 32)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Dietary preference")
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 32)

                    Picker("Diet", selection: $dietaryPreference) {
                        ForEach(DietaryPreference.allCases, id: \.self) { pref in
                            Text(pref.rawValue).tag(pref)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 32)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Region")
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 32)

                    Picker("Region", selection: $regionPreference) {
                        ForEach(CarbonRegionPreference.allCases) { preference in
                            Text(preference.rawValue).tag(preference)
                        }
                    }
                    .pickerStyle(.navigationLink)
                    .padding(.horizontal, 32)
                }
            }

            Text("We use your region to translate travel distance, money saved, and a sensible starting goal.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            Button {
                focusedField = nil
                withAnimation { step = 2 }
            } label: {
                Text("Next")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
            .accessibilityHint("Moves to your daily goal")
        }
    }

    // MARK: - Step 2: Daily Goal

    private var goalStep: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "target")
                .font(.system(size: 60))
                .foregroundStyle(.green)

            Text("Your Daily Goal")
                .font(.title.bold())

            VStack(spacing: 8) {
                Text("\(Int(goalPercent.rounded()))% of a typical day")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundStyle(.green)

                Text(String(format: "%.1f kg CO₂ / day", goalTargetKgPerDay))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
            }

            goalPresetRow

            VStack(spacing: 10) {
                Slider(value: $goalPercent, in: 50...120, step: 5)
                    .tint(.green)
                    .padding(.horizontal, 40)

                HStack {
                    Text("50%")
                    Spacer()
                    Text("120%")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 40)
            }

            VStack(spacing: 8) {
                Text("Typical daily footprint for \(selectedRegion.displayName): \(selectedRegion.averageDailyFootprintText).")
                    .font(.subheadline.weight(.medium))
                    .multilineTextAlignment(.center)
                Text(goalExplainerText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)

            VStack(alignment: .leading, spacing: 10) {
                goalCallout(
                    icon: "sparkles",
                    text: "Choose a percentage first if kilograms do not mean much yet."
                )
                goalCallout(
                    icon: "banknote.fill",
                    text: "You can always edit the goal later once your savings and routines feel clearer."
                )
            }
            .padding(18)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .padding(.horizontal, 24)

            Spacer()

            Button {
                finish()
            } label: {
                if isSaving {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Finish")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .disabled(isSaving)
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
            .accessibilityHint("Saves your profile and requests permissions")
        }
    }

    private func finish() {
        isSaving = true
        Task {
            do {
                let profile = try await DataStore.shared.fetchUserProfile()
                profile.name = userName.isEmpty ? "Green Explorer" : userName
                profile.dietaryPreference = dietaryPreference
                profile.regionPreference = regionPreference
                profile.targetKgPerDay = goalTargetKgPerDay
                profile.hasCompletedOnboarding = true
                try await DataStore.shared.saveProfile(profile)

                await NotificationManager.shared.requestAuthorization()
                await HealthKitManager.shared.requestAuthorization()
                LocationManager.shared.requestPassiveCommutePermission()

                isPresented = false
            } catch {
                isSaving = false
            }
        }
    }

    private var selectedRegion: CarbonRegion {
        regionPreference.resolved()
    }

    private var goalTargetKgPerDay: Double {
        selectedRegion.recommendedDailyTargetKg * (goalPercent / 100)
    }

    private var goalExplainerText: String {
        let delta = selectedRegion.recommendedDailyTargetKg - goalTargetKgPerDay

        if delta >= 0 {
            return "This aims for about \(String(format: "%.1f", delta)) kg less than a typical day in your area."
        }

        return "This gives you a softer starting goal while you learn your baseline."
    }

    private var stepTitles: [String] {
        [
            "What GreenCatalyst helps with",
            "Set up your profile",
            "Choose a goal you can understand",
        ]
    }

    private var stepSubtitles: [String] {
        [
            "Clearer guidance, less carbon math.",
            "A small amount of context makes the nudges more useful.",
            "Pick a percentage of a typical day, then we translate it back to kg.",
        ]
    }

    private func onboardingPoint(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.green)
                .frame(width: 18)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private var goalPresetRow: some View {
        HStack(spacing: 10) {
            goalPresetButton(title: "Easy", percent: 100)
            goalPresetButton(title: "Focused", percent: 85)
            goalPresetButton(title: "Stretch", percent: 70)
        }
        .padding(.horizontal, 24)
    }

    private func goalPresetButton(title: String, percent: Double) -> some View {
        Button {
            goalPercent = percent
        } label: {
            VStack(spacing: 4) {
                Text(title)
                    .font(.caption.weight(.semibold))
                Text("\(Int(percent))%")
                    .font(.subheadline.bold())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(goalPercent == percent ? Color.green : Color(.secondarySystemGroupedBackground))
            .foregroundStyle(goalPercent == percent ? .white : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private func goalCallout(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.green)
                .frame(width: 18)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}
