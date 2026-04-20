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
    @State private var targetKgPerDay: Double = CarbonRegionPreference.automatic
        .resolved()
        .recommendedDailyTargetKg
    @State private var isSaving: Bool = false

    private enum Field {
        case userName
    }

    var body: some View {
        VStack(spacing: 0) {
            // Step indicator
            HStack(spacing: 8) {
                ForEach(0..<3) { i in
                    Capsule()
                        .fill(i <= step ? Color.green : Color.gray.opacity(0.3))
                        .frame(height: 4)
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
        .onChange(of: regionPreference) { _, newValue in
            targetKgPerDay = newValue.resolved().recommendedDailyTargetKg
        }
    }

    // MARK: - Step 0: Local Setup

    private var appleSignInStep: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "leaf.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green)

            VStack(spacing: 8) {
                Text("Set up your profile")
                    .font(.title.bold())
                Text("This build stores your profile on-device and focuses on honest, manual tracking.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            VStack(alignment: .leading, spacing: 12) {
                onboardingPoint(icon: "chart.bar.fill", text: "Guided calculators help you estimate transport, food, energy, and shopping impact.")
                onboardingPoint(icon: "heart.fill", text: "HealthKit imports are estimates derived from workout data, not verified commute detection.")
                onboardingPoint(icon: "waveform.circle.fill", text: "Shortcuts support quick voice logging, but they are managed through the Shortcuts app.")
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

            Text(String(format: "%.1f kg CO₂", targetKgPerDay))
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(.green)

            Slider(value: $targetKgPerDay, in: 2...15, step: 0.5)
                .tint(.green)
                .padding(.horizontal, 40)

            Text("Regional planning baseline: \(selectedRegion.averageDailyFootprintText) per day.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

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
                profile.targetKgPerDay = targetKgPerDay
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
}
