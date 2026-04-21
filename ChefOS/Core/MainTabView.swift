//
//  MainTabView.swift
//  ChefOS
//

import SwiftUI

// MARK: - Core

struct MainTabView: View {
    @State private var selectedTab: Tab = .recipes
    @StateObject private var planViewModel = PlanViewModel()
    @StateObject private var shoppingViewModel = ShoppingListViewModel()
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
        .tint(AppColors.primary)
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
        .toolbarBackgroundVisibility(.visible, for: .tabBar)
        .environmentObject(planViewModel)
        .environmentObject(shoppingViewModel)
        // ── Chat Action Layer: wire chat card actions to real app state ─────
        // When the chat dispatches an action, we update VM state immediately
        // (optimistic). The confirmation card from ChatViewModel lands in the
        // same run-loop → user sees both UI update and feedback as one event.
        .onReceive(NotificationCenter.default.publisher(for: .chatDidAddRecipeToPlan)) { note in
            guard let card = note.object as? APIClient.BackendRecipeCard else { return }
            let recipe = Recipe(from: card)
            planViewModel.addRecipeToPlan(recipe)
        }
        .onReceive(NotificationCenter.default.publisher(for: .chatDidAddToShoppingList)) { note in
            guard let card = note.object as? APIClient.BackendProductCard else { return }
            shoppingViewModel.add(
                name: card.name,
                note: "from chat",
                source: .manual,
                productId: card.slug
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .chatDidRequestCooking)) { note in
            guard let card = note.object as? APIClient.BackendRecipeCard else { return }
            // Bring the full recipe into the plan AND switch to it — the user
            // asked to cook right now. Future: open a dedicated CookingView.
            let recipe = Recipe(from: card)
            planViewModel.addRecipeToPlan(recipe)
            selectedTab = .plan
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(RegionService())
        .environmentObject(AuthService())
        .environmentObject(UsageService())
        .preferredColorScheme(.dark)
}
