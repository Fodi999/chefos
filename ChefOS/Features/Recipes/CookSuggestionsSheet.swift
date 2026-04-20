import SwiftUI

// MARK: - Cook Suggestions Sheet (main list)

struct CookSuggestionsSheet: View {
    @ObservedObject var vm: CookSuggestionsViewModel
    @EnvironmentObject var l10n: LocalizationService
    @EnvironmentObject var regionService: RegionService
    @EnvironmentObject var favVM: FavoritesViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient.screenBackground
                    .ignoresSafeArea()

                if vm.isLoading {
                    VStack(spacing: 16) {
                        ProgressView().scaleEffect(1.5)
                        Text(l10n.t("cook.analyzing"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else if let error = vm.errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle).foregroundStyle(.orange)
                        Text(error).font(.caption).foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button(l10n.t("cook.retry")) {
                            Task { await vm.loadSuggestions() }
                        }.buttonStyle(.borderedProminent)
                    }.padding()
                } else if vm.isEmpty && vm.hasLoaded {
                    VStack(spacing: 12) {
                        Image(systemName: "basket")
                            .font(.system(size: 48)).foregroundStyle(.secondary)
                        Text(l10n.t("cook.empty"))
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            if let insight = vm.inventoryInsight {
                                inventoryInsightCard(insight)
                            }
                            if !vm.canCook.isEmpty {
                                dishSection(title: l10n.t("cook.canCookNow"), icon: "checkmark.circle.fill", color: .green, dishes: vm.canCook)
                            }
                            if !vm.almost.isEmpty {
                                dishSection(title: l10n.t("cook.almostReady"), icon: "minus.circle.fill", color: .orange, dishes: vm.almost)
                            }
                            if !vm.strategic.isEmpty {
                                dishSection(title: l10n.t("cook.strategic"), icon: "brain.head.profile", color: .purple, dishes: vm.strategic)
                            }
                            if let unlock = vm.unlockSuggestions, !unlock.unlockHints.isEmpty {
                                unlockCard(unlock)
                            }
                        }.padding()
                    }
                }
            }
            .navigationTitle(l10n.t("cook.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                }
            }
            .sheet(item: $vm.selectedDish) { dish in
                RecipeDetailSheet(dish: dish)
                    .environmentObject(l10n)
                    .environmentObject(favVM)
            }
        }
    }

    // MARK: - Inventory Insight

    @ViewBuilder
    private func inventoryInsightCard(_ insight: APIClient.InventoryInsight) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 16) {
                insightMetric(icon: "refrigerator.fill", value: "\(insight.totalIngredients)", label: l10n.t("cook.ingredients"))
                insightMetric(icon: "calendar.badge.clock", value: "~\(insight.daysLeft)", label: l10n.t("cook.daysLeft"))
                insightMetric(icon: "exclamationmark.triangle.fill", value: "\(insight.wasteRisk)%", label: l10n.t("cook.wasteRisk"), color: insight.wasteRisk > 30 ? .red : .orange)
            }
            if !insight.atRisk.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "clock.badge.exclamationmark").font(.caption2).foregroundStyle(.orange)
                    Text(insight.atRisk.joined(separator: ", ")).font(.caption2).foregroundStyle(.orange).lineLimit(2)
                }
            }
        }
        .padding(14).frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.blue.opacity(0.3), lineWidth: 1))
    }

    private func insightMetric(icon: String, value: String, label: String, color: Color = .blue) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.title3).foregroundStyle(color)
            Text(value).font(.headline.weight(.bold))
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity)
    }

    // MARK: - Unlock Card

    @ViewBuilder
    private func unlockCard(_ unlock: APIClient.UnlockSuggestions) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "lightbulb.fill").foregroundStyle(.yellow)
                Text(l10n.t("cook.unlockMore")).font(.headline.weight(.bold))
            }
            ForEach(unlock.unlockHints, id: \.self) { hint in
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill").font(.caption).foregroundStyle(.green)
                    Text(hint).font(.caption)
                }
            }
            if !unlock.missingFrequently.isEmpty {
                FlowLayout(spacing: 4) {
                    ForEach(unlock.missingFrequently, id: \.self) { name in
                        Text(name).font(.caption2).padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Color.yellow.opacity(0.15), in: Capsule()).foregroundStyle(.orange)
                    }
                }
            }
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.yellow.opacity(0.3), lineWidth: 1))
    }

    // MARK: - Section

    @ViewBuilder
    private func dishSection(title: String, icon: String, color: Color, dishes: [APIClient.SuggestedDish]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: icon).foregroundStyle(color)
                Text(title).font(.headline.weight(.bold))
                Spacer()
                Text("\(dishes.count)").font(.caption.weight(.bold)).foregroundStyle(.white)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(color.opacity(0.8), in: Capsule())
            }
            ForEach(dishes) { dish in
                Button { vm.selectedDish = dish } label: { dishCard(dish, accentColor: color) }
                    .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Dish Card

    @ViewBuilder
    private func dishCard(_ dish: APIClient.SuggestedDish, accentColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(dish.displayName ?? dish.dishNameLocal ?? dish.dishName)
                        .font(.subheadline.weight(.bold))
                    HStack(spacing: 6) {
                        dishTypeBadge(dish.dishType)
                        complexityBadge(dish.complexity)
                    }
                }
                Spacer()
                HStack(spacing: 4) {
                    if dish.insight.usesExpiring { insightBadge("⏰", color: .orange) }
                    if dish.insight.highProtein { insightBadge("💪", color: .blue) }
                    if dish.insight.budgetFriendly { insightBadge("💰", color: .green) }
                }
            }

            HStack(spacing: 12) {
                nutritionPill("🔥", "\(dish.perServingKcal)")
                nutritionPill("P", String(format: "%.0fg", dish.perServingProteinG))
                nutritionPill("F", String(format: "%.0fg", dish.perServingFatG))
                nutritionPill("C", String(format: "%.0fg", dish.perServingCarbsG))
                Spacer()
                Text("🍽 \(dish.servings)").font(.caption2).foregroundStyle(.secondary)
            }

            if let flavor = dish.flavor {
                HStack(spacing: 6) {
                    flavorBar(score: flavor.balanceScore)
                    if let dom = flavor.dominant { Text(dom).font(.caption2).foregroundStyle(.secondary) }
                }
            }

            if !dish.steps.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "list.number").font(.caption2).foregroundStyle(.secondary)
                    Text("\(dish.steps.count) \(l10n.t("cook.steps"))").font(.caption2).foregroundStyle(.secondary)
                    if let totalTime = dish.steps.compactMap(\.timeMin).reduce(0, +) as Int?, totalTime > 0 {
                        Text("• ~\(totalTime) \(l10n.t("cook.min"))").font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }

            // ── PRIMARY ACTION BUTTON ──
            if dish.missingCount == 0 {
                Label(l10n.t("cook.cookNow"), systemImage: "flame.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.green, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                Label(l10n.t("cook.addMissing"), systemImage: "cart.badge.plus")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.orange, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(accentColor.opacity(0.3), lineWidth: 1))
    }

    // MARK: - Helpers

    private func flavorBar(score: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.gray.opacity(0.2))
                Capsule()
                    .fill(score > 0.7 ? Color.green : score > 0.4 ? Color.orange : Color.red)
                    .frame(width: geo.size.width * score)
            }
        }.frame(width: 50, height: 6)
    }

    private func dishTypeBadge(_ type: String) -> some View {
        let icon: String = { switch type {
        case "soup": return "drop.fill"
        case "stew": return "flame.fill"
        case "salad": return "leaf.fill"
        case "grill": return "flame"
        case "pasta": return "fork.knife"
        default: return "circle"
        }}()
        return Image(systemName: icon).font(.caption2).foregroundStyle(.secondary)
    }

    private func complexityBadge(_ complexity: String) -> some View {
        let dots: String = { switch complexity {
        case "easy": return "●○○"
        case "medium": return "●●○"
        case "hard": return "●●●"
        default: return "●○○"
        }}()
        return Text(dots).font(.caption2).foregroundStyle(.secondary)
    }

    private func insightBadge(_ emoji: String, color: Color) -> some View {
        Text(emoji).font(.caption).padding(4).background(color.opacity(0.15), in: Circle())
    }

    private func nutritionPill(_ label: String, _ value: String) -> some View {
        HStack(spacing: 2) {
            Text(label).font(.caption2.weight(.bold))
            Text(value).font(.caption2)
        }.foregroundStyle(.secondary)
    }
}

// MARK: - Recipe Detail Sheet

struct RecipeDetailSheet: View {
    let dish: APIClient.SuggestedDish
    @EnvironmentObject var l10n: LocalizationService
    @EnvironmentObject var favVM: FavoritesViewModel
    @Environment(\.dismiss) private var dismiss
    @StateObject private var shoppingVM = ShoppingListViewModel()
    @State private var showCookMode = false
    @State private var showAddedToast = false
    @State private var cookingComplete = false

    private var canCookNow: Bool { dish.missingCount == 0 }

    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        headerSection
                        actionButtons
                        if !dish.insight.reasons.isEmpty { reasonsSection }
                        nutritionSection
                        if let flavor = dish.flavor { flavorSection(flavor) }
                        if let adaptation = dish.adaptation, adaptation.changed { adaptationSection(adaptation) }
                        ingredientsSection
                        if !dish.steps.isEmpty { stepsSection }
                        if !dish.warnings.isEmpty { warningsSection }
                        if !dish.tags.isEmpty || !dish.allergens.isEmpty { tagsSection }
                        Color.clear.frame(height: 20) // bottom padding
                    }.padding()
                }

                // Toast
                if showAddedToast {
                    VStack {
                        Spacer()
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                            Text(l10n.t("cook.addedToShoppingList"))
                                .font(.subheadline.weight(.medium))
                        }
                        .padding(.horizontal, 20).padding(.vertical, 12)
                        .background(.ultraThickMaterial, in: Capsule())
                        .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
                        .padding(.bottom, 30)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(10)
                }
            }
            .background(LinearGradient.screenBackground.ignoresSafeArea())
            .navigationTitle(dish.displayName ?? dish.dishNameLocal ?? dish.dishName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { favVM.toggle(dish) } label: {
                        Image(systemName: favVM.isFavorite(dish.dishName) ? "heart.fill" : "heart")
                            .foregroundStyle(favVM.isFavorite(dish.dishName) ? .red : .secondary)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                }
            }
            .fullScreenCover(isPresented: $showCookMode) {
                CookModeView(dish: dish, onComplete: {
                    cookingComplete = true
                    showCookMode = false
                })
                .environmentObject(l10n)
            }
            .sheet(isPresented: $cookingComplete) {
                CookingCompleteSheet(dish: dish)
                    .environmentObject(l10n)
            }
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 10) {
            if canCookNow {
                Button {
                    showCookMode = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "flame.fill").font(.title3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(l10n.t("cook.cookNow")).font(.headline.weight(.bold))
                            if let totalTime = dish.steps.compactMap(\.timeMin).reduce(0, +) as Int?, totalTime > 0 {
                                Text("~\(totalTime) \(l10n.t("cook.min")) • \(dish.steps.count) \(l10n.t("cook.steps"))")
                                    .font(.caption).opacity(0.8)
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .foregroundStyle(.white)
                    .padding(16)
                    .background(
                        LinearGradient(colors: [.green, .green.opacity(0.8)], startPoint: .leading, endPoint: .trailing),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )
                    .shadow(color: .green.opacity(0.3), radius: 8, y: 4)
                }
            } else {
                Button {
                    addMissingToShoppingList()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "cart.badge.plus").font(.title3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(l10n.t("cook.addMissing")).font(.headline.weight(.bold))
                            Text("\(dish.missingCount) \(l10n.t("cook.ingredientsMissing"))")
                                .font(.caption).opacity(0.8)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .foregroundStyle(.white)
                    .padding(16)
                    .background(
                        LinearGradient(colors: [.orange, .orange.opacity(0.8)], startPoint: .leading, endPoint: .trailing),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )
                    .shadow(color: .orange.opacity(0.3), radius: 8, y: 4)
                }
            }
        }
    }

    private func addMissingToShoppingList() {
        let dishName = dish.displayName ?? dish.dishNameLocal ?? dish.dishName
        for name in dish.missingIngredients {
            shoppingVM.add(
                name: name,
                note: l10n.t("cook.forRecipe") + " " + dishName,
                source: .recipeSuggestion
            )
        }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            showAddedToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { showAddedToast = false }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(dish.displayName ?? dish.dishNameLocal ?? dish.dishName)
                .font(.title2.weight(.bold))
            HStack(spacing: 12) {
                Label(dish.dishType.capitalized, systemImage: "fork.knife").font(.caption)
                Label(dish.complexity.capitalized, systemImage: "speedometer").font(.caption)
                Label("\(dish.servings)", systemImage: "person.2").font(.caption)
            }.foregroundStyle(.secondary)
        }
    }

    // MARK: - Why This Dish

    private var reasonsSection: some View {
        sectionCard(title: l10n.t("cook.whyThisDish"), icon: "lightbulb.fill", color: .yellow) {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(dish.insight.reasons, id: \.self) { reason in
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill").font(.caption).foregroundStyle(.green)
                        Text(localizeReason(reason)).font(.subheadline)
                    }
                }
            }
        }
    }

    // MARK: - Nutrition

    private var nutritionSection: some View {
        sectionCard(title: l10n.t("cook.nutrition"), icon: "chart.bar.fill", color: .blue) {
            VStack(spacing: 8) {
                Text(l10n.t("cook.perServing")).font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 0) {
                    nutritionBlock("🔥", "\(dish.perServingKcal)", l10n.t("cook.kcal"))
                    nutritionBlock("🥩", String(format: "%.1f", dish.perServingProteinG), l10n.t("cook.protein"))
                    nutritionBlock("🧈", String(format: "%.1f", dish.perServingFatG), l10n.t("cook.fat"))
                    nutritionBlock("🍞", String(format: "%.1f", dish.perServingCarbsG), l10n.t("cook.carbs"))
                }
            }
        }
    }

    private func nutritionBlock(_ emoji: String, _ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(emoji).font(.title3)
            Text(value).font(.headline.weight(.bold))
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity)
    }

    // MARK: - Flavor

    private func flavorSection(_ flavor: APIClient.FlavorInfo) -> some View {
        sectionCard(title: l10n.t("cook.flavorProfile"), icon: "sparkles", color: .purple) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(l10n.t("cook.balance")).font(.caption)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.gray.opacity(0.2))
                            Capsule()
                                .fill(flavor.balanceScore > 0.7 ? Color.green : flavor.balanceScore > 0.4 ? Color.orange : Color.red)
                                .frame(width: geo.size.width * flavor.balanceScore)
                        }
                    }.frame(height: 8)
                    Text(String(format: "%.0f%%", flavor.balanceScore * 100)).font(.caption.weight(.bold))
                }
                if let dominant = flavor.dominant {
                    HStack(spacing: 4) {
                        Text(l10n.t("cook.dominant")).font(.caption).foregroundStyle(.secondary)
                        Text(dominant.capitalized).font(.caption.weight(.bold))
                    }
                }
                if !flavor.suggestions.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(l10n.t("cook.canImprove")).font(.caption).foregroundStyle(.secondary)
                        ForEach(flavor.suggestions, id: \.self) { s in
                            HStack(spacing: 4) {
                                Image(systemName: "plus.circle").font(.caption2).foregroundStyle(.orange)
                                Text(localizeFlavorSuggestion(s)).font(.caption)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Adaptation

    private func adaptationSection(_ adaptation: APIClient.AdaptationInfo) -> some View {
        sectionCard(title: l10n.t("cook.adapted"), icon: "arrow.triangle.2.circlepath", color: .cyan) {
            VStack(alignment: .leading, spacing: 6) {
                if let strategy = adaptation.strategy {
                    HStack(spacing: 4) {
                        Text(l10n.t("cook.optimizedFor")).font(.caption).foregroundStyle(.secondary)
                        Text(strategy.replacingOccurrences(of: "_", with: " ").capitalized).font(.caption.weight(.bold))
                    }
                }
                ForEach(adaptation.actions, id: \.self) { action in
                    HStack(spacing: 6) {
                        Image(systemName: "wrench.and.screwdriver").font(.caption2).foregroundStyle(.cyan)
                        Text(action).font(.caption)
                    }
                }
            }
        }
    }

    // MARK: - Ingredients

    private var ingredientsSection: some View {
        sectionCard(title: l10n.t("cook.ingredientsList"), icon: "basket.fill", color: .green) {
            VStack(spacing: 6) {
                ForEach(dish.ingredients, id: \.slug) { ing in
                    HStack {
                        Circle()
                            .fill(ing.available ? (ing.expiringSoon ? Color.orange : Color.green) : Color.red.opacity(0.5))
                            .frame(width: 8, height: 8)
                        Text(ing.name).font(.subheadline)
                        Spacer()
                        Text(String(format: "%.0fg", ing.grossG)).font(.caption).foregroundStyle(.secondary)
                        Text(ing.role).font(.caption2).padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.1), in: Capsule())
                    }
                }
                if !dish.missingIngredients.isEmpty {
                    Divider()
                    HStack(spacing: 4) {
                        Image(systemName: "cart.badge.plus").font(.caption).foregroundStyle(.red)
                        Text(l10n.t("cook.needToBuy") + ": " + dish.missingIngredients.joined(separator: ", "))
                            .font(.caption).foregroundStyle(.red.opacity(0.8))
                    }
                }
            }
        }
    }

    // MARK: - Steps

    private var stepsSection: some View {
        sectionCard(title: l10n.t("cook.cookingSteps"), icon: "list.number", color: .orange) {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(dish.steps) { step in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(step.step)")
                            .font(.caption.weight(.bold)).foregroundStyle(.white)
                            .frame(width: 24, height: 24).background(Color.orange, in: Circle())
                        VStack(alignment: .leading, spacing: 4) {
                            Text(step.text).font(.subheadline)
                            HStack(spacing: 8) {
                                if let time = step.timeMin {
                                    Label("\(time) \(l10n.t("cook.min"))", systemImage: "clock").font(.caption2).foregroundStyle(.secondary)
                                }
                                if let temp = step.tempC {
                                    Label("\(temp)°C", systemImage: "thermometer.medium").font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                            if let tip = step.tip {
                                HStack(spacing: 4) {
                                    Image(systemName: "lightbulb.fill").font(.caption2).foregroundStyle(.yellow)
                                    Text(tip).font(.caption2).foregroundStyle(.secondary).italic()
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Warnings

    private var warningsSection: some View {
        sectionCard(title: l10n.t("cook.warnings"), icon: "exclamationmark.triangle.fill", color: .yellow) {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(dish.warnings, id: \.self) { w in
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle").font(.caption).foregroundStyle(.yellow)
                        Text(w).font(.caption)
                    }
                }
            }
        }
    }

    // MARK: - Tags

    private var tagsSection: some View {
        sectionCard(title: l10n.t("cook.tags"), icon: "tag.fill", color: .indigo) {
            FlowLayout(spacing: 6) {
                ForEach(dish.tags, id: \.self) { tag in
                    Text(tag).font(.caption2).padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.green.opacity(0.15), in: Capsule())
                }
                ForEach(dish.allergens, id: \.self) { a in
                    Text("⚠️ " + a).font(.caption2).padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.red.opacity(0.15), in: Capsule())
                }
            }
        }
    }

    // MARK: - Section Card

    private func sectionCard<Content: View>(title: String, icon: String, color: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon).foregroundStyle(color)
                Text(title).font(.headline.weight(.bold))
            }
            content()
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Localization

    private func localizeReason(_ reason: String) -> String {
        switch reason {
        case "uses_expiring_ingredients": return l10n.t("cook.reason.expiring")
        case "high_protein": return l10n.t("cook.reason.protein")
        case "all_ingredients_available": return l10n.t("cook.reason.allAvailable")
        case "budget_friendly": return l10n.t("cook.reason.budget")
        default: return reason.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    private func localizeFlavorSuggestion(_ s: String) -> String {
        switch s {
        case "add_acidity": return l10n.t("cook.flavor.addAcidity")
        case "add_sweetness": return l10n.t("cook.flavor.addSweet")
        case "add_moisture": return l10n.t("cook.flavor.addMoisture")
        case "reduce_bitterness": return l10n.t("cook.flavor.reduceBitter")
        case "consider_umami": return l10n.t("cook.flavor.addUmami")
        case "dish_too_flat": return l10n.t("cook.flavor.flat")
        default: return s.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }
}
