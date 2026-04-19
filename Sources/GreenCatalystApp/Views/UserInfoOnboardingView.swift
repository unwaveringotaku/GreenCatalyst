import SwiftUI
import AuthenticationServices

// MARK: - UserInfoOnboardingView

struct UserInfoOnboardingView: View {

    @Binding var isPresented: Bool
    @State private var step: Int = 0

    // Form state
    @State private var userName: String = ""
    @State private var userEmail: String? = nil
    @State private var appleUserID: String? = nil
    @State private var dietaryPreference: DietaryPreference = .omnivore
    @State private var targetKgPerDay: Double = 8.0
    @State private var isSaving: Bool = false
    @State private var signInErrorMessage: String? = nil

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

            TabView(selection: $step) {
                appleSignInStep.tag(0)
                profileStep.tag(1)
                goalStep.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: step)
        }
        .background(Color(.systemGroupedBackground))
        .alert("Sign In Unavailable", isPresented: signInErrorIsPresented) {
            Button("OK") {
                signInErrorMessage = nil
            }
        } message: {
            Text(signInErrorMessage ?? "")
        }
    }

    // MARK: - Step 0: Sign In with Apple

    private var appleSignInStep: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "leaf.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green)

            VStack(spacing: 8) {
                Text("Let's personalise")
                    .font(.title.bold())
                Text("Sign in to save your profile across devices and reinstalls.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                handleAppleSignIn(result)
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 50)
            .padding(.horizontal, 40)

            Button("Continue without signing in") {
                withAnimation { step = 1 }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

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
            }

            Spacer()

            Button {
                withAnimation { step = 2 }
            } label: {
                Text("Next")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
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

            Text("The average person emits about 8 kg CO₂ per day.")
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
        }
    }

    // MARK: - Actions

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
                appleUserID = credential.user
                if let givenName = credential.fullName?.givenName {
                    userName = givenName
                    if let familyName = credential.fullName?.familyName {
                        userName += " " + familyName
                    }
                }
                userEmail = credential.email
            }
            withAnimation { step = 1 }
        case .failure:
            signInErrorMessage = "Sign in with Apple is unavailable in this build. Continue without signing in, or enable the capability on a supported Apple Developer team."
        }
    }

    private func finish() {
        isSaving = true
        Task {
            do {
                let profile = try await DataStore.shared.fetchUserProfile()
                profile.name = userName.isEmpty ? "Green Explorer" : userName
                profile.email = userEmail
                profile.appleUserIdentifier = appleUserID
                profile.dietaryPreference = dietaryPreference
                profile.targetKgPerDay = targetKgPerDay
                profile.hasCompletedOnboarding = true
                try await DataStore.shared.saveProfile(profile)

                CloudProfileStore.shared.backupProfile(profile, appleUserID: appleUserID)

                await NotificationManager.shared.requestAuthorization()
                await HealthKitManager.shared.requestAuthorization()

                isPresented = false
            } catch {
                isSaving = false
            }
        }
    }

    private var signInErrorIsPresented: Binding<Bool> {
        Binding(
            get: { signInErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    signInErrorMessage = nil
                }
            }
        )
    }
}
