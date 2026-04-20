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
                        ProgressView()
                            .controlSize(.large)
                            .tint(.secondary)
                        Text(l10n.t("cook.analyzing"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else if let error = vm.errorMessage {
                    ContentUnavailableView {
                        Label(l10n.t("cook.retry"), systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error)
                    } actions: {
                        Button(l10n.t("cook.retry")) {
                            Task { await vm.loadSuggestions() }
                        }.buttonStyle(.borderedProminent).tint(.orange)
                    }
                } else if vm.isEmpty && vm.hasLoaded {
                    ContentUnavailableView(
                        l10n.t("cook.empty"),
                        systemImage: "basket",
                        description: Text(l10n.t("cook.empty"))
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 24) {
                            if let p = vm.personalization, p.personalized {
                                personalizationBanner(p)
                            }
                            if let insight = vm.inventoryInsight {
                                inventoryInsightCard(insight)
                            }
                            if !vm.canCook.isEmpty {
                                dishSection(title: l10n.t("cook.canCookNow"), icon: "checkmark.seal.fill", color: .green, dishes: vm.canCook)
                            }
                            if !vm.almost.isEmpty {
                                dishSection(title: l10n.t("cook.almostReady"), icon: "ellipsis.circle.fill", color: .orange, dishes: vm.almost)
                            }
                            if !vm.strategic.isEmpty {
                                dishSection(title: l10n.t("cook.strategic"), icon: "brain.head.profile.fill", color: .purple, dishes: vm.strategic)
                            }
                            if let unlock = vm.unlockSuggestions, !unlock.unlockHints.isEmpty {
                                unlockCard(unlock)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }
                }
            }
            .navigationTitle(l10n.t("cook.title"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .sheet(item: $vm.selectedDish) { dish in
            RecipeDetailSheet(dish: dish)
                .environmentObject(l10n)
                .environmentObject(favVM)
        }
    }

    // MARK: - Personalization Banner

    @ViewBuilder
    private func personalizationBanner(_ p: APIClient.PersonalizationInfo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "person.badge.shield.checkmark.fill")
                    .font(.title3)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.indigo)
                Text(l10n.t("cook.personalizedForYou"))
                    .font(.subheadline.weight(.semibold))
            }

            FlowLayout(spacing: 6) {
                infoPill(icon: goalIcon(p.goal), text: localizeGoal(p.goal), color: .indigo)
                if p.diet != "no_restrictions" {
                    infoPill(icon: "leaf.fill", text: localizeDiet(p.diet), color: .green)
                }
                infoPill(icon: "flame.fill", text: "\(p.kcalTarget) \(l10n.t("cook.kcal"))", color: .orange)
                infoPill(icon: "figure.strengthtraining.traditional", text: "\(p.proteinTarget)g", color: .blue)
            }

            if !p.excludedAllergens.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.shield.fill")
                        .font(.caption2).foregroundStyle(.red)
                    Text(p.excludedAllergens.joined(separator: " · "))
                        .font(.caption).foregroundStyle(.red.opacity(0.8))
                }
            }
            if !p.excludedDislikes.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "hand.thumbsdown.fill")
                        .font(.caption2).foregroundStyle(.secondary)
                    Text(p.excludedDislikes.joined(separator: " · "))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(
                    LinearGradient(colors: [.indigo.opacity(0.3), .purple.opacity(0.15)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 0.5
                )
        )
    }

    private func infoPill(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.caption2.weight(.semibold))
            Text(text).font(.caption.weight(.medium))
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(color.opacity(0.12), in: Capsule())
        .foregroundStyle(color)
    }

    // MARK: - Helpers

    private func goalIcon(_ goal: String) -> String {
        switch goal {
        case "lose_weight", "low_calorie", "cut": return "flame.fill"
        case "gain_muscle", "high_protein", "bulk": return "figure.strengthtraining.traditional"
        case "gain_weight", "mass": return "arrow.up.circle.fill"
        case "eat_healthier": return "heart.fill"
        default: return "target"
        }
    }

    private func localizeGoal(_ goal: String) -> String {
        switch goal {
        case "lose_weight", "low_calorie", "cut": return l10n.t("cook.goal.loseWeight")
        case "gain_muscle", "high_protein", "bulk": return l10n.t("cook.goal.gainMuscle")
        case "gain_weight", "mass": return l10n.t("cook.goal.gainWeight")
        case "eat_healthier": return l10n.t("cook.goal.eatHealthier")
        default: return l10n.t("cook.goal.balanced")
        }
    }

    private func localizeDiet(_ diet: String) -> String {
        switch diet {
        case "vegan": return l10n.t("cook.diet.vegan")
        case "vegetarian": return l10n.t("cook.diet.vegetarian")
        case "pescatarian": return l10n.t("cook.diet.pescatarian")
        case "keto": return l10n.t("cook.diet.keto")
        default: return diet.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    // MARK: - Inventory Insight

    @ViewBuilder
    private func inventoryInsightCard(_ insight: APIClient.InventoryInsight) -> some View {
        HStack(spacing: 0) {
            insightMetric(icon: "refrigerator.fill", value: "\(insight.totalIngredients)", label: l10n.t("cook.ingredients"), color: .blue)
            Divider().frame(height: 32).opacity(0.3)
            insightMetric(icon: "calendar.badge.clock", value: "~\(insight.daysLeft)d", label: l10n.t("cook.daysLeft"), color: .cyan)
            Divider().frame(height: 32).opacity(0.3)
            insightMetric(icon: "exclamationmark.triangle.fill", value: "\(insight.wasteRisk)%", label: l10n.t("cook.wasteRisk"), color: insight.wasteRisk > 30 ? .red : .orange)
        }
        .padding(.vertical, 14).frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5))
    }

    private func insightMetric(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.body).symbolRenderingMode(.hierarchical).foregroundStyle(color)
            Text(value).font(.subheadline.weight(.bold)).monospacedDigit()
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity)
    }

    // MARK: - Unlock Card

    @ViewBuilder
    private func unlockCard(_ unlock: APIClient.UnlockSuggestions) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.max.fill").symbolRenderingMode(.hierarchical).foregroundStyle(.yellow)
                Text(l10n.t("cook.unlockMore")).font(.subheadline.weight(.semibold))
            }
            ForEach(unlock.unlockHints, id: \.self) { hint in
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill").font(.caption).foregroundStyle(.green)
                    Text(hint).font(.caption)
                }
            }
            if !unlock.missingFrequently.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(unlock.missingFrequently, id: \.self) { name in
                        Text(name).font(.caption2.weight(.medium))
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(Color.yellow.opacity(0.1), in: Capsule())
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Color.yellow.opacity(0.2), lineWidth: 0.5))
    }

    // MARK: - Section

    @ViewBuilder
    private func dishSection(title: String, icon: String, color: Color, dishes: [APIClient.SuggestedDish]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: icon).symbolRenderingMode(.hierarchical).foregroundStyle(color)
                Text(title).font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(dishes.count)").font(.caption.weight(.bold)).monospacedDigit()
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(color, in: Capsule())
            }
            ForEach(dishes) { dish in
                dishCard(dish, accentColor: color)
                    .contentShape(.rect(cornerRadius: 20))
                    .onTapGesture { vm.selectedDish = dish }
            }
        }
    }

    // MARK: - Dish Card

    @ViewBuilder
    private func dishCard(_ dish: APIClient.SuggestedDish, accentColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(dish.displayName ?? dish.dishNameLocal ?? dish.dishName)
                        .font(.subheadline.weight(.semibold)).lineLimit(2)
                    HStack(spacing: 8) {
                        Label(dish.dishType.capitalized, systemImage: dishTypeIcon(dish.dishType))
                        Label(dish.complexity.capitalized, systemImage: "gauge.medium")
                    }.font(.caption2).foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                HStack(spacing: 6) {
                    if favVM.isFavorite(dish.dishName) {
                        Image(systemName: "heart.fill").font(.caption).foregroundStyle(.red)
                    }
                    if dish.insight.usesExpiring { sfBadge(icon: "clock.badge.exclamationmark", color: .orange) }
                    if dish.insight.highProtein { sfBadge(icon: "figure.strengthtraining.traditional", color: .blue) }
                    if dish.insight.budgetFriendly { sfBadge(icon: "dollarsign.circle.fill", color: .green) }
                }
            }

            // Nutrition
            HStack(spacing: 0) {
                nutritionCell(icon: "flame.fill", value: "\(dish.perServingKcal)", unit: l10n.t("cook.kcal"), color: .orange)
                nutritionCell(icon: "p.circle.fill", value: String(format: "%.0f", dish.perServingProteinG), unit: "g", color: .blue)
                nutritionCell(icon: "f.circle.fill", value: String(format: "%.0f", dish.perServingFatG), unit: "g", color: .yellow)
                nutritionCell(icon: "c.circle.fill", value: String(format: "%.0f", dish.perServingCarbsG), unit: "g", color: .green)
                Spacer()
                Label("\(dish.servings)", systemImage: "person.2.fill").font(.caption2).foregroundStyle(.secondary)
            }

            // Smart Badges
            if let p = vm.personalization, p.personalized {
                FlowLayout(spacing: 6) {
                    if dish.insight.highProtein {
                        smartPill(icon: "figure.strengthtraining.traditional", text: l10n.t("cook.badge.highProtein"), color: .blue)
                    }
                    if dish.perServingKcal <= p.kcalTarget / 3 {
                        smartPill(icon: "flame.fill", text: l10n.t("cook.badge.lowCal"), color: .green)
                    }
                    if !p.excludedAllergens.isEmpty {
                        smartPill(icon: "checkmark.shield.fill", text: l10n.t("cook.badge.allergenFree"), color: .mint)
                    }
                    if let totalTime = dish.steps.compactMap(\.timeMin).reduce(0, +) as Int?, totalTime > 0, totalTime <= 20 {
                        smartPill(icon: "bolt.fill", text: l10n.t("cook.badge.quick"), color: .orange)
                    }
                    if dish.insight.budgetFriendly {
                        smartPill(icon: "dollarsign.circle.fill", text: l10n.t("cook.badge.budget"), color: .green)
                    }
                }
            }

            // Flavor
            if let flavor = dish.flavor {
                HStack(spacing: 8) {
                    flavorBar(score: flavor.balanceScore)
                    if let dom = flavor.dominant { Text(dom.capitalized).font(.caption2).foregroundStyle(.secondary) }
                }
            }

            // Steps
            if !dish.steps.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "list.bullet").font(.caption2).foregroundStyle(.secondary)
                    Text("\(dish.steps.count) \(l10n.t("cook.steps"))").font(.caption2).foregroundStyle(.secondary)
                    if let totalTime = dish.steps.compactMap(\.timeMin).reduce(0, +) as Int?, totalTime > 0 {
                        Text("·").foregroundStyle(.quaternary)
                        Image(systemName: "clock").font(.caption2).foregroundStyle(.secondary)
                        Text("~\(totalTime) \(l10n.t("cook.min"))").font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }

            // CTA
            HStack(spacing: 8) {
                Image(systemName: dish.missingCount == 0 ? "play.fill" : "book.fill").font(.caption.weight(.semibold))
                Text(l10n.t("cook.openRecipe")).font(.caption.weight(.semibold))
                Spacer()
                if dish.missingCount > 0 {
                    Text("\(dish.missingCount) \(l10n.t("cook.missing"))").font(.caption2.weight(.medium))
                }
                Image(systemName: "chevron.right").font(.caption2.weight(.bold)).foregroundStyle(.tertiary)
            }
            .foregroundStyle(dish.missingCount == 0 ? .green : .orange)
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background((dish.missingCount == 0 ? Color.green : Color.orange).opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(accentColor.opacity(0.15), lineWidth: 0.5))
    }

    // MARK: - Small Helpers

    private func flavorBar(score: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.08))
                Capsule().fill(score > 0.7 ? Color.green : score > 0.4 ? Color.orange : Color.red)
                    .frame(width: geo.size.width * score)
            }
        }.frame(width: 50, height: 5)
    }

    private func dishTypeIcon(_ type: String) -> String {
        switch type {
        case "soup": return "drop.fill"
        case "stew": return "flame.fill"
        case "salad": return "leaf.fill"
        case "grill": return "flame"
        case "pasta": return "fork.knife"
        default: return "circle.fill"
        }
    }

    private func sfBadge(icon: String, color: Color) -> some View {
        Image(systemName: icon).font(.caption2).symbolRenderingMode(.hierarchical)
            .foregroundStyle(color).padding(5).background(color.opacity(0.1), in: Circle())
    }

    private func nutritionCell(icon: String, value: String, unit: String, color: Color) -> some View {
        HStack(spacing: 2) {
            Image(systemName: icon).font(.system(size: 9)).foregroundStyle(color)
            Text(value + unit).font(.caption2.weight(.medium)).monospacedDigit()
        }.foregroundStyle(.secondary).padding(.trailing, 10)
    }

    private func smartPill(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 9))
            Text(text).font(.caption2.weight(.medium))
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(color.opacity(0.1), in: Capsule())
        .foregroundStyle(color)
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
                    VStack(alignment: .leading, spacing: 24) {
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
                        Color.clear.frame(height: 24)
                    }.padding(.horizontal).padding(.top, 8)
                }

                if showAddedToast {
                    VStack {
                        Spacer()
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                            Text(l10n.t("cook.addedToShoppingList")).font(.subheadline.weight(.medium))
                        }
                        .padding(.horizontal, 20).padding(.vertical, 12)
                        .background(.ultraThickMaterial, in: Capsule())
                        .shadow(color: .black.opacity(0.15), radius: 12, y: 6)
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
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(favVM.isFavorite(dish.dishName) ? .red : .secondary)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill").symbolRenderingMode(.hierarchical).foregroundStyle(.secondary)
                    }
                }
            }
            .fullScreenCover(isPresented: $showCookMode) {
                CookModeView(dish: dish, onComplete: { cookingComplete = true; showCookMode = false })
                    .environmentObject(l10n)
            }
            .sheet(isPresented: $cookingComplete) {
                CookingCompleteSheet(dish: dish).environmentObject(l10n)
            }
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 10) {
            if canCookNow {
                Button { showCookMode = true } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "play.fill").font(.title3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(l10n.t("cook.cookNow")).font(.subheadline.weight(.bold))
                            if let totalTime = dish.steps.compactMap(\.timeMin).reduce(0, +) as Int?, totalTime > 0 {
                                Text("~\(totalTime) \(l10n.t("cook.min")) · \(dish.steps.count) \(l10n.t("cook.steps"))")
                                    .font(.caption).opacity(0.8)
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption.weight(.bold))
                    }
                    .foregroundStyle(.white).padding(16)
                    .background(.green.gradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            } else {
                Button { addMissingToShoppingList() } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "cart.badge.plus").font(.title3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(l10n.t("cook.addMissing")).font(.subheadline.weight(.bold))
                            Text("\(dish.missingCount) \(l10n.t("cook.ingredientsMissing"))").font(.caption).opacity(0.8)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption.weight(.bold))
                    }
                    .foregroundStyle(.white).padding(16)
                    .background(.orange.gradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
        }
    }

    private func addMissingToShoppingList() {
        let dishName = dish.displayName ?? dish.dishNameLocal ?? dish.dishName
        for name in dish.missingIngredients {
            shoppingVM.add(name: name, note: l10n.t("cook.forRecipe") + " " + dishName, source: .recipeSuggestion)
        }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { showAddedToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { withAnimation { showAddedToast = false } }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(dish.displayName ?? dish.dishNameLocal ?? dish.dishName).font(.title2.weight(.bold))
            HStack(spacing: 14) {
                Label(dish.dishType.capitalized, systemImage: "fork.knife")
                Label(dish.complexity.capitalized, systemImage: "gauge.medium")
                Label("\(dish.servings)", systemImage: "person.2")
            }.font(.caption).foregroundStyle(.secondary)
        }
    }

    // MARK: - Reasons

    private var reasonsSection: some View {
        sectionCard(title: l10n.t("cook.whyThisDish"), icon: "lightbulb.max.fill", color: .yellow) {
            VStack(alignment: .leading, spacing: 8) {
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
            VStack(spacing: 10) {
                Text(l10n.t("cook.perServing")).font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 0) {
                    nutritionBlock(icon: "flame.fill", value: "\(dish.perServingKcal)", label: l10n.t("cook.kcal"), color: .orange)
                    nutritionBlock(icon: "p.circle.fill", value: String(format: "%.1f", dish.perServingProteinG), label: l10n.t("cook.protein"), color: .blue)
                    nutritionBlock(icon: "f.circle.fill", value: String(format: "%.1f", dish.perServingFatG), label: l10n.t("cook.fat"), color: .yellow)
                    nutritionBlock(icon: "c.circle.fill", value: String(format: "%.1f", dish.perServingCarbsG), label: l10n.t("cook.carbs"), color: .green)
                }
            }
        }
    }

    private func nutritionBlock(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.title3).symbolRenderingMode(.hierarchical).foregroundStyle(color)
            Text(value).font(.subheadline.weight(.bold)).monospacedDigit()
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity)
    }

    // MARK: - Flavor

    private func flavorSection(_ flavor: APIClient.FlavorInfo) -> some View {
        sectionCard(title: l10n.t("cook.flavorProfile"), icon: "sparkles", color: .purple) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(l10n.t("cook.balance")).font(.caption)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.primary.opacity(0.08))
                            Capsule().fill(flavor.balanceScore > 0.7 ? Color.green : flavor.balanceScore > 0.4 ? Color.orange : Color.red)
                                .frame(width: geo.size.width * flavor.balanceScore)
                        }
                    }.frame(height: 6)
                    Text(String(format: "%.0f%%", flavor.balanceScore * 100)).font(.caption.weight(.bold)).monospacedDigit()
                }
                if let dominant = flavor.dominant {
                    HStack(spacing: 6) {
                        Text(l10n.t("cook.dominant")).font(.caption).foregroundStyle(.secondary)
                        Text(dominant.capitalized).font(.caption.weight(.bold))
                    }
                }
                if !flavor.suggestions.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(l10n.t("cook.canImprove")).font(.caption).foregroundStyle(.secondary)
                        ForEach(flavor.suggestions, id: \.self) { s in
                            HStack(spacing: 6) {
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
            VStack(alignment: .leading, spacing: 8) {
                if let strategy = adaptation.strategy {
                    HStack(spacing: 6) {
                        Text(l10n.t("cook.optimizedFor")).font(.caption).foregroundStyle(.secondary)
                        Text(strategy.replacingOccurrences(of: "_", with: " ").capitalized).font(.caption.weight(.bold))
                    }
                }
                ForEach(adaptation.actions, id: \.self) { action in
                    HStack(spacing: 8) {
                        Image(systemName: "gearshape.fill").font(.caption2).foregroundStyle(.cyan)
                        Text(action).font(.caption)
                    }
                }
            }
        }
    }

    // MARK: - Ingredients

    private var ingredientsSection: some View {
        sectionCard(title: l10n.t("cook.ingredientsList"), icon: "basket.fill", color: .green) {
            VStack(spacing: 8) {
                ForEach(dish.ingredients, id: \.slug) { ing in
                    HStack(spacing: 10) {
                        Circle().fill(ing.available ? (ing.expiringSoon ? Color.orange : Color.green) : Color.red.opacity(0.5))
                            .frame(width: 7, height: 7)
                        Text(ing.name).font(.subheadline)
                        Spacer()
                        Text(String(format: "%.0fg", ing.grossG)).font(.caption).monospacedDigit().foregroundStyle(.secondary)
                        Text(ing.role).font(.caption2).padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Color.primary.opacity(0.06), in: Capsule())
                    }
                }
                if !dish.missingIngredients.isEmpty {
                    Divider().opacity(0.5)
                    HStack(spacing: 6) {
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
            VStack(alignment: .leading, spacing: 16) {
                ForEach(dish.steps) { step in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(step.step)").font(.caption.weight(.bold)).foregroundStyle(.white)
                            .frame(width: 26, height: 26).background(.orange.gradient, in: Circle())
                        VStack(alignment: .leading, spacing: 6) {
                            Text(step.text).font(.subheadline)
                            HStack(spacing: 10) {
                                if let time = step.timeMin {
                                    Label("\(time) \(l10n.t("cook.min"))", systemImage: "clock").font(.caption2).foregroundStyle(.secondary)
                                }
                                if let temp = step.tempC {
                                    Label("\(temp)°C", systemImage: "thermometer.medium").font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                            if let tip = step.tip {
                                HStack(spacing: 6) {
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
            VStack(alignment: .leading, spacing: 8) {
                ForEach(dish.warnings, id: \.self) { w in
                    HStack(spacing: 8) {
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
                    Text(tag).font(.caption2.weight(.medium))
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Color.green.opacity(0.1), in: Capsule())
                }
                ForEach(dish.allergens, id: \.self) { a in
                    HStack(spacing: 3) {
                        Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 8))
                        Text(a)
                    }.font(.caption2.weight(.medium))
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Color.red.opacity(0.1), in: Capsule())
                    .foregroundStyle(.red)
                }
            }
        }
    }

    // MARK: - Section Card

    private func sectionCard<Content: View>(title: String, icon: String, color: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon).symbolRenderingMode(.hierarchical).foregroundStyle(color)
                Text(title).font(.subheadline.weight(.semibold))
            }
            content()
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
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
