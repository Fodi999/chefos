//
//  MainTabView.swift
//  ChefOS
//

import SwiftUI

// MARK: - Core

struct MainTabView: View {
    @State private var selectedTab: Tab = .recipes
    @StateObject private var planViewModel = PlanViewModel()
    @EnvironmentObject var l10n: LocalizationService

    enum Tab: String {
        case recipes, plan, chat, profile
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            RecipesView()
                .tabItem {
                    Label(l10n.t("tab.recipes"), systemImage: "refrigerator.fill")
                }
                .tag(Tab.recipes)

            PlanView()
                .tabItem {
                    Label(l10n.t("tab.plan"), systemImage: "calendar")
                }
                .tag(Tab.plan)

            ChatView()
                .tabItem {
                    Label(l10n.t("tab.chat"), systemImage: "sparkles")
                }
                .tag(Tab.chat)

            ProfileView()
                .tabItem {
                    Label(l10n.t("tab.profile"), systemImage: "person.crop.circle")
                }
                .tag(Tab.profile)
        }
        .tint(Color.auroraBlue)
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
        .toolbarBackgroundVisibility(.visible, for: .tabBar)
        .environmentObject(planViewModel)
    }
}

#Preview {
    MainTabView()
        .environmentObject(RegionService())
        .environmentObject(AuthService())
        .environmentObject(UsageService())
        .preferredColorScheme(.dark)
}
