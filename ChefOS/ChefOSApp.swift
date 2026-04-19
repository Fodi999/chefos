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
    @StateObject private var l10n = LocalizationService()

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
            .onAppear {
                authService.determineInitialState()
            }
        }
    }
}
