//
//  OnboardingView.swift
//  ChefOS
//

import SwiftUI

// MARK: - Features/Onboarding

struct OnboardingView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var regionService: RegionService
    @EnvironmentObject var usageService: UsageService
    @EnvironmentObject var l10n: LocalizationService
    @State private var step: OnboardingStep = .welcome
    @State private var appeared = false
    @State private var logoScale: CGFloat = 0.6
    @State private var detecting = true

    // Auth form fields
    @State private var isLoginMode = true
    @State private var email = ""
    @State private var password = ""
    @State private var name = ""
    @FocusState private var focusedField: AuthField?

    enum AuthField { case name, email, password }

    enum OnboardingStep {
        case welcome
        case auth
        case biometrics
    }

    var body: some View {
        ZStack {
            // Background
            AppColors.background
                .ignoresSafeArea()

            switch step {
            case .welcome:
                welcomeStep
            case .auth:
                authStep
            case .biometrics:
                biometricsStep
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.6)) {
                appeared = true
                logoScale = 1.0
            }
            // Simulate detection
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation(.easeOut(duration: 0.4)) {
                    detecting = false
                }
            }
        }
    }

    // MARK: - Welcome Step

    private var welcomeStep: some View {
        VStack(spacing: 0) {
            Spacer()

            // Logo
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(AppColors.accent)
                        .frame(width: 100, height: 100)
                    Image(systemName: "fork.knife")
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .scaleEffect(logoScale)

                Text(l10n.t("onboarding.welcome"))
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.white)

                Text(l10n.t("onboarding.subtitle"))
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .opacity(appeared ? 1 : 0)

            Spacer().frame(height: 50)

            // Region detection
            VStack(spacing: 16) {
                if detecting {
                    HStack(spacing: 10) {
                        ProgressView()
                            .tint(.orange)
                        Text(l10n.t("onboarding.detecting"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .transition(.opacity)
                } else {
                    // Country card
                    VStack(spacing: 14) {
                        HStack(spacing: 12) {
                            Text(regionService.countryFlag)
                                .font(.system(size: 36))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(regionService.countryName)
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(.white)
                                Text("\(l10n.t("onboarding.currency")) \(regionService.currency)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.green)
                        }
                        .padding(18)
                        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.green.opacity(0.1), lineWidth: 1)
                        )

                        // Change country
                        NavigationLink {
                            CountryPickerView(regionService: regionService)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "globe")
                                    .font(.caption)
                                Text(l10n.t("onboarding.changeCountry"))
                                    .font(.caption.weight(.semibold))
                            }
                            .foregroundStyle(.orange)
                        }
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .frame(height: 120)
            .padding(.horizontal, 24)

            Spacer()

            // Continue button
            Button {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    step = .auth
                }
            } label: {
                Text(l10n.t("onboarding.continue"))
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AppColors.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .padding(.horizontal, 24)
            .opacity(detecting ? 0.4 : 1)
            .disabled(detecting)

            Spacer().frame(height: 40)
        }
    }

    // MARK: - Auth Step

    private var authStep: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 20) {
                Image(systemName: "person.badge.key.fill")
                    .font(.system(size: 50, weight: .light))
                    .foregroundStyle(AppColors.primary)

                Text(isLoginMode ? l10n.t("onboarding.signIn") : l10n.t("onboarding.createAccount"))
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)

                Text(isLoginMode ? l10n.t("onboarding.welcomeBack") : l10n.t("onboarding.startJourney"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer().frame(height: 40)

            VStack(spacing: 14) {
                if !isLoginMode {
                    authTextField(icon: "person.fill", placeholder: l10n.t("onboarding.kitchenName"), text: $name)
                        .focused($focusedField, equals: .name)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .email }
                }

                authTextField(icon: "envelope.fill", placeholder: l10n.t("onboarding.email"), text: $email)
                    .focused($focusedField, equals: .email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .password }

                authTextField(icon: "lock.fill", placeholder: l10n.t("onboarding.password"), text: $password, isSecure: true)
                    .focused($focusedField, equals: .password)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.go)

                if !isLoginMode {
                    Text(l10n.t("onboarding.passwordHint"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 4)
                }
            }
            .padding(.horizontal, 24)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    focusedField = isLoginMode ? .email : .name
                }
            }

            if let error = authService.error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.top, 8)
                    .padding(.horizontal, 24)
                    .multilineTextAlignment(.center)
            }

            Spacer().frame(height: 30)

            // Submit button
            Button {
                Task {
                    let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)

                    if isLoginMode {
                        await authService.loginWithBackend(email: trimmedEmail, password: trimmedPassword)
                    } else {
                        await authService.registerWithBackend(email: trimmedEmail, password: trimmedPassword, name: name.trimmingCharacters(in: .whitespacesAndNewlines))
                    }

                    if authService.hasRealSession {
                        usageService.grantWelcomeBonus()
                        authService.checkBiometricType()
                        if authService.biometricType != .none {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                step = .biometrics
                            }
                        } else {
                            authService.completeOnboarding(enableBiometrics: false)
                        }
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    if authService.isLoading {
                        ProgressView()
                            .tint(.white)
                    }
                    Text(isLoginMode ? l10n.t("onboarding.signIn") : l10n.t("onboarding.createAccount"))
                        .font(.headline.weight(.bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(AppColors.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .disabled(authService.isLoading || email.isEmpty || password.isEmpty || (!isLoginMode && name.isEmpty))
            .opacity((email.isEmpty || password.isEmpty) ? 0.5 : 1)
            .padding(.horizontal, 24)

            // Toggle login/register
            Button {
                withAnimation(.easeOut(duration: 0.2)) {
                    isLoginMode.toggle()
                    authService.error = nil
                }
            } label: {
                Text(isLoginMode ? "\(l10n.t("onboarding.noAccount")) **\(l10n.t("onboarding.signUp"))**" : "\(l10n.t("onboarding.haveAccount")) **\(l10n.t("onboarding.signIn"))**")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 16)
            }

            Spacer().frame(height: 40)
        }
        .transition(.move(edge: .trailing).combined(with: .opacity))
    }

    private func authTextField(icon: String, placeholder: String, text: Binding<String>, isSecure: Bool = false) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 20)

            if isSecure {
                SecureField(placeholder, text: text)
                    .foregroundStyle(.white)
                    .tint(.orange)
            } else {
                TextField(placeholder, text: text)
                    .foregroundStyle(.white)
                    .tint(.orange)
            }
        }
        .padding(14)
        .background(AppColors.surfaceRaised, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.04), lineWidth: 0.5)
        )
    }

    // MARK: - Biometrics Step

    private var biometricsStep: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 24) {
                ZStack {
                    Image(systemName: authService.biometricIcon)
                        .font(.system(size: 60, weight: .light))
                        .foregroundStyle(Color.cyan)
                }

                VStack(spacing: 8) {
                    Text("\(l10n.t("onboarding.enableBiometric")) \(authService.biometricLabel)?")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                    Text("\(l10n.t("onboarding.secureAccess")) \(authService.biometricLabel)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }

            Spacer()

            VStack(spacing: 12) {
                Button {
                    authService.completeOnboarding(enableBiometrics: true)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: authService.biometricIcon)
                        Text("\(l10n.t("onboarding.enableBiometric")) \(authService.biometricLabel)")
                            .font(.headline.weight(.bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.cyan, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                Button {
                    authService.skipBiometrics()
                } label: {
                    Text(l10n.t("onboarding.maybeLater"))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 12)
                }
            }
            .padding(.horizontal, 24)

            Spacer().frame(height: 40)
        }
        .transition(.move(edge: .trailing).combined(with: .opacity))
    }
}

// MARK: - Lock Screen

struct LockScreenView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var l10n: LocalizationService

    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()

            VStack(spacing: 30) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(AppColors.accent)
                        .frame(width: 80, height: 80)
                    Image(systemName: "fork.knife")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(.white)
                }

                Text("ChefOS")
                    .font(.title.weight(.bold))
                    .foregroundStyle(.white)

                Spacer()

                // Unlock
                Button {
                    authService.authenticateWithBiometrics()
                } label: {
                    VStack(spacing: 12) {
                        Image(systemName: authService.biometricIcon)
                            .font(.system(size: 44, weight: .light))
                            .foregroundStyle(.white.opacity(0.9))
                            .symbolEffect(.bounce, options: .repeating.speed(0.2))

                        Text(l10n.t("onboarding.tapToUnlock"))
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }

                if authService.isLoading {
                    ProgressView()
                        .tint(.orange)
                }

                if let error = authService.error {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }

                Spacer().frame(height: 60)
            }
        }
        .onAppear {
            // Auto-trigger biometric on appear
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                authService.authenticateWithBiometrics()
            }
        }
    }
}

// MARK: - Country Picker

struct CountryPickerView: View {
    @ObservedObject var regionService: RegionService
    @EnvironmentObject var l10n: LocalizationService
    @Environment(\.dismiss) var dismiss
    @State private var search = ""

    var filteredCountries: [RegionService.Country] {
        if search.isEmpty { return RegionService.supportedCountries }
        return RegionService.supportedCountries.filter {
            $0.name.localizedCaseInsensitiveContains(search) ||
            $0.code.localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()

            List {
                ForEach(filteredCountries) { country in
                    Button {
                        regionService.setCountry(country)
                        dismiss()
                    } label: {
                        HStack(spacing: 14) {
                            Text(country.flag)
                                .font(.title2)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(country.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                                Text(country.currencySymbol)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if country.code == regionService.countryCode {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(Color.white.opacity(0.04))
                }
            }
            .scrollContentBackground(.hidden)
            .searchable(text: $search, prompt: l10n.t("onboarding.searchCountries"))
        }
        .navigationTitle(l10n.t("onboarding.country"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        OnboardingView()
            .environmentObject(AuthService())
            .environmentObject(RegionService())
            .environmentObject(UsageService())
            .environmentObject(LocalizationService())
    }
    .preferredColorScheme(.dark)
}
