//
//  MainTabView.swift
//  ChefOS
//

import SwiftUI

// MARK: - Core

struct MainTabView: View {
    @State private var selectedTab: Tab = .chat
    @StateObject private var planViewModel = PlanViewModel()
    @EnvironmentObject var l10n: LocalizationService

    enum Tab: String {
        case chat, recipes, plan, profile
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            ChatView()
                .tabItem {
                    Label(l10n.t("tab.chat"), systemImage: "bubble.left.and.bubble.right.fill")
                }
                .tag(Tab.chat)

            RecipesView()
                .tabItem {
                    Label(l10n.t("tab.recipes"), systemImage: "book.fill")
                }
                .tag(Tab.recipes)

            PlanView()
                .tabItem {
                    Label(l10n.t("tab.plan"), systemImage: "calendar")
                }
                .tag(Tab.plan)

            ProfileView()
                .tabItem {
                    Label(l10n.t("tab.profile"), systemImage: "person.fill")
                }
                .tag(Tab.profile)
        }
        .tint(.orange)
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
