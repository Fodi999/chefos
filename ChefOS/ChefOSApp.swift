//
//  ChefOSApp.swift
//  ChefOS
//
//  Created by Дмитрий Фомин on 18/04/2026.
//

import SwiftUI

@main
struct ChefOSApp: App {
    @StateObject private var authService = AuthService()
    @StateObject private var regionService = RegionService()
    @StateObject private var usageService = UsageService()
    @StateObject private var l10n = LocalizationService.shared
    @State private var designSystem = DesignSystem.shared
    @State private var showSessionExpiredAlert = false

    var body: some Scene {
        WindowGroup {
            Group {
                switch authService.state {
                case .onboarding:
                    NavigationStack {
                        OnboardingView()
                    }
                case .locked:
                    LockScreenView()
                case .authenticated:
                    MainTabView()
                }
            }
            .preferredColorScheme(.dark)
            .environmentObject(authService)
            .environmentObject(regionService)
            .environmentObject(usageService)
            .environmentObject(l10n)
            .environment(designSystem)
            .alert(
                sessionExpiredTitle,
                isPresented: $showSessionExpiredAlert
            ) {
                Button(sessionExpiredConfirm) { }
            } message: {
                Text(sessionExpiredBody)
            }
            .onAppear {
                authService.determineInitialState()
                // Push cached Keychain tokens into APIClient so private
                // endpoints work immediately after relaunch — without this
                // APIClient.accessToken would be nil and every write would
                // fail with 401 until the user logs in again manually.
                authService.rehydrateAPIClient()
                // Wire the APIClient → AuthService bridge once. If the
                // access token + refresh token both fail, the API client
                // invokes this callback; we wipe local state and bounce
                // the user back to onboarding / login automatically.
                APIClient.shared.onSessionExpired = { [weak authService] in
                    authService?.logout()
                    showSessionExpiredAlert = true
                }
                // Ask for notification permission once — iOS itself
                // deduplicates the prompt if the user already answered.
                Task { await NotificationService.shared.requestAuthorization() }
            }
        }
    }

    // MARK: - Localized alert strings

    private var sessionExpiredTitle: String {
        switch l10n.language {
        case "en": return "Session expired"
        case "pl": return "Sesja wygasła"
        case "uk": return "Сесія закінчилася"
        default:   return "Сессия истекла"
        }
    }

    private var sessionExpiredBody: String {
        switch l10n.language {
        case "en": return "Please sign in again to continue."
        case "pl": return "Zaloguj się ponownie, aby kontynuować."
        case "uk": return "Увійдіть знову, щоб продовжити."
        default:   return "Пожалуйста, войдите снова, чтобы продолжить."
        }
    }

    private var sessionExpiredConfirm: String {
        switch l10n.language {
        case "en": return "Sign in"
        case "pl": return "Zaloguj"
        case "uk": return "Увійти"
        default:   return "Войти"
        }
    }
}
