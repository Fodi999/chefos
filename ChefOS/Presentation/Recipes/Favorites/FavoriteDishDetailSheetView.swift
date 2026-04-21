// MARK: - Presentation/Recipes/Favorites/FavoriteDishDetailSheet.swift
// Extracted from RecipesView.swift as part of DDD refactoring

import SwiftUI

struct FavoriteDishDetailSheetView: View {
    let fav: FavoriteDish
    @EnvironmentObject var l10n: LocalizationService
    @EnvironmentObject var favVM: FavoritesViewModel
    @Environment(\.dismiss) private var dismiss
    @StateObject private var shoppingVM = ShoppingListViewModel()
    @State private var showAddedToast = false

    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        headerSection
                        actionButtons
                        nutritionSection
                        if !fav.ingredients.isEmpty { ingredientsSection }
                        if !fav.steps.isEmpty { stepsSection }
                        if !fav.missingIngredients.isEmpty { missingSection }
                        if !fav.warnings.isEmpty { warningsSection }
                        if !fav.tags.isEmpty || !fav.allergens.isEmpty { tagsSection }
                        if !fav.insight.reasons.isEmpty { reasonsSection }
                        Color.clear.frame(height: 24)
                    }
                    .padding(.horizontal).padding(.top, 8)
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
            .navigationTitle(fav.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        withAnimation { favVM.toggle(fav) }
                    } label: {
                        Image(systemName: favVM.isFavorite(fav) ? "heart.fill" : "heart")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(favVM.isFavorite(fav) ? .red : .secondary)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .symbolRenderingMode(.hierarchical).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(fav.displayName).font(.title2.weight(.bold))
            HStack(spacing: 14) {
                Label(localizedDishType(fav.dishType), systemImage: "fork.knife")
                Label(localizedComplexity(fav.complexity), systemImage: "gauge.medium")
                Label("\(fav.servings)", systemImage: "person.2")
            }.font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 8) {
                if fav.insight.usesExpiring  { pill("⏰ " + l10n.t("cook.badge.expiring"), color: .orange) }
                if fav.insight.highProtein   { pill("💪 " + l10n.t("cook.badge.highProtein"), color: .blue) }
                if fav.insight.budgetFriendly { pill("💰 " + l10n.t("cook.badge.budget"), color: .green) }
            }
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 10) {
            if !fav.missingIngredients.isEmpty {
                Button { addMissingToShoppingList() } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "cart.badge.plus").font(.title3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(l10n.t("cook.addMissing")).font(.subheadline.weight(.bold))
                            Text("\(fav.missingCount) \(l10n.t("cook.ingredientsMissing"))").font(.caption).opacity(0.8)
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
        for name in fav.missingIngredients {
            shoppingVM.add(name: name, note: l10n.t("cook.forRecipe") + " " + fav.displayName, source: .recipeSuggestion)
        }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { showAddedToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { withAnimation { showAddedToast = false } }
    }

    // MARK: - Nutrition

    private var nutritionSection: some View {
        sectionCard(title: l10n.t("cook.nutrition"), icon: "chart.bar.fill", color: .blue) {
            VStack(spacing: 10) {
                Text(l10n.t("cook.perServing")).font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 0) {
                    nutritionBlock(icon: "flame.fill",    value: "\(fav.perServingKcal)",                       label: l10n.t("cook.kcal"),    color: .orange)
                    nutritionBlock(icon: "p.circle.fill", value: String(format: "%.1f", fav.perServingProteinG), label: l10n.t("cook.protein"), color: .blue)
                    nutritionBlock(icon: "f.circle.fill", value: String(format: "%.1f", fav.perServingFatG),     label: l10n.t("cook.fat"),     color: .yellow)
                    nutritionBlock(icon: "c.circle.fill", value: String(format: "%.1f", fav.perServingCarbsG),   label: l10n.t("cook.carbs"),   color: .green)
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

    // MARK: - Ingredients

    private var ingredientsSection: some View {
        sectionCard(title: l10n.t("cook.ingredientsList"), icon: "basket.fill", color: .green) {
            VStack(spacing: 8) {
                ForEach(fav.ingredients, id: \.slug) { ing in
                    HStack(spacing: 10) {
                        Circle()
                            .fill(ing.available ? (ing.expiringSoon ? Color.orange : Color.green) : Color.red.opacity(0.5))
                            .frame(width: 7, height: 7)
                        Text(ing.name).font(.subheadline)
                        Spacer()
                        if ing.grossG > 0 {
                            Text(ing.grossG.truncatingRemainder(dividingBy: 1) == 0
                                 ? "\(Int(ing.grossG))g" : String(format: "%.1fg", ing.grossG))
                            .font(.caption).monospacedDigit().foregroundStyle(.secondary)
                        }
                        Text(localizedRole(ing.role)).font(.caption2)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Color.primary.opacity(0.06), in: Capsule())
                    }
                }
            }
        }
    }

    // MARK: - Missing

    private var missingSection: some View {
        sectionCard(title: l10n.t("cook.needToBuy"), icon: "cart.badge.plus", color: .red) {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(fav.missingIngredients, id: \.self) { name in
                    HStack(spacing: 8) {
                        Circle().fill(Color.red.opacity(0.5)).frame(width: 6, height: 6)
                        Text(name).font(.subheadline)
                    }
                }
            }
        }
    }

    // MARK: - Steps

    private var stepsSection: some View {
        sectionCard(title: l10n.t("cook.cookingSteps"), icon: "list.number", color: .orange) {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(fav.steps, id: \.step) { step in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(step.step)").font(.caption.weight(.bold)).foregroundStyle(.white)
                            .frame(width: 26, height: 26).background(.orange.gradient, in: Circle())
                        VStack(alignment: .leading, spacing: 6) {
                            Text(step.text).font(.subheadline)
                            HStack(spacing: 10) {
                                if let t = step.timeMin {
                                    Label("\(t) \(l10n.t("cook.min"))", systemImage: "clock")
                                        .font(.caption2).foregroundStyle(.secondary)
                                }
                                if let temp = step.tempC {
                                    Label("\(temp)°C", systemImage: "thermometer.medium")
                                        .font(.caption2).foregroundStyle(.secondary)
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
                ForEach(fav.warnings, id: \.self) { w in
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle").font(.caption).foregroundStyle(.yellow)
                        Text(w).font(.caption)
                    }
                }
            }
        }
    }

    // MARK: - Tags & Allergens

    private var tagsSection: some View {
        sectionCard(title: l10n.t("cook.tags"), icon: "tag.fill", color: .indigo) {
            FlowLayout(spacing: 6) {
                ForEach(fav.tags, id: \.self) { tag in
                    Label {
                        Text(localizeTag(tag)).font(.caption2.weight(.medium))
                    } icon: {
                        Image(systemName: iconForTag(tag)).font(.system(size: 9))
                    }
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Color.green.opacity(0.1), in: Capsule())
                    .foregroundStyle(Color.green.opacity(0.9))
                }
                ForEach(fav.allergens, id: \.self) { a in
                    HStack(spacing: 3) {
                        Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 8))
                        Text(localizeAllergen(a))
                    }.font(.caption2.weight(.medium))
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Color.red.opacity(0.1), in: Capsule())
                    .foregroundStyle(.red)
                }
            }
        }
    }

    // MARK: - Why this dish

    private var reasonsSection: some View {
        sectionCard(title: l10n.t("cook.whyThisDish"), icon: "lightbulb.max.fill", color: .yellow) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(fav.insight.reasons, id: \.self) { reason in
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill").font(.caption).foregroundStyle(.green)
                        Text(localizeReason(reason)).font(.subheadline)
                    }
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

    // MARK: - Localization Helpers

    private func pill(_ text: String, color: Color) -> some View {
        Text(text).font(.caption2.weight(.medium))
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(color.opacity(0.12), in: Capsule())
            .foregroundStyle(color)
    }

    private func localizedDishType(_ type: String) -> String {
        let key = "dishType.\(type)"; let r = l10n.t(key)
        return r == key ? type.replacingOccurrences(of: "_", with: " ").capitalized : r
    }

    private func localizedComplexity(_ c: String) -> String {
        let key = "complexity.\(c)"; let r = l10n.t(key)
        return r == key ? c.capitalized : r
    }

    private func localizedRole(_ role: String) -> String {
        let key = "role.\(role)"; let r = l10n.t(key)
        return r == key ? role.replacingOccurrences(of: "_", with: " ").capitalized : r
    }

    private func localizeReason(_ reason: String) -> String {
        switch reason {
        case "uses_expiring_ingredients": return l10n.t("cook.reason.expiring")
        case "high_protein":             return l10n.t("cook.reason.protein")
        case "all_ingredients_available":return l10n.t("cook.reason.allAvailable")
        case "budget_friendly":          return l10n.t("cook.reason.budget")
        case "fits_goal":                return l10n.t("cook.reason.fitsGoal")
        case "uses_inventory":           return l10n.t("cook.reason.usesInventory")
        default: return reason.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    private func localizeTag(_ tag: String) -> String {
        let key = "tag.\(tag)"; let r = l10n.t(key)
        return r == key ? tag.replacingOccurrences(of: "_", with: " ").capitalized : r
    }

    private func iconForTag(_ tag: String) -> String {
        switch tag {
        case "uses_expiring_ingredients": return "clock.badge.exclamationmark"
        case "high_protein":              return "bolt.fill"
        case "all_ingredients_available": return "checkmark.circle.fill"
        case "budget_friendly":           return "dollarsign.circle.fill"
        case "low_calorie":               return "flame"
        case "high_calorie":              return "flame.fill"
        case "vegetarian":                return "leaf.fill"
        case "vegan":                     return "leaf"
        case "gluten_free":               return "xmark.circle"
        case "dairy_free":                return "drop.triangle"
        case "quick":                     return "hare.fill"
        case "seasonal":                  return "sun.max.fill"
        case "spicy":                     return "thermometer.high"
        case "high_fiber":                return "chart.bar.fill"
        case "low_carb":                  return "minus.circle"
        default:                          return "tag"
        }
    }

    private func localizeAllergen(_ allergen: String) -> String {
        let key = "allergen.\(allergen.lowercased())"; let r = l10n.t(key)
        return r == key ? allergen.capitalized : r
    }
}
