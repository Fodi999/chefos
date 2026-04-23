
//
//  MealRow.swift
//  ChefOS — Presentation/Plan/Components
//
//  Expandable meal row — показывает рецепт и разворачивается по тапу.
//
//  ✅ Правила:
//    - Цвета:    только SemanticColors.nutrient/meal/state/tag
//    - Шрифты:   только .appStyle(.tag / .nutrientValue / .sectionTitle / ...)
//    - Фоны:     только .surface(.card) / .surface(.tag(.calories)) / .glassCard()
//    - Отступы:  только Spacing.* / Radius.*
//

import SwiftUI

// MARK: - MealRow

struct MealRow: View {
    let meal: Meal
    let isLoading: Bool
    var isExpanded: Bool = false
    var currency: String = "$"
    @ObservedObject var favVM: FavoritesViewModel
    var onAdd: () -> Void
    var onClear: () -> Void
    var onTap: () -> Void
    @EnvironmentObject var l10n: LocalizationService

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            mealHeader
                .padding(.bottom, 12)
            
            if let recipe = meal.recipe {
                recipeRow(recipe)
                
                if isExpanded {
                    expandedDetail(recipe: recipe)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .padding(.top, 16)
                }
            } else {
                addMealButton
                    .padding(.top, 4)
            }
        }
        .padding(16)
        .background {
            ZStack {
                AppColors.surface
                
                if isExpanded {
                    LinearGradient(
                        colors: [mealIconColor.opacity(0.05), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(isExpanded ? mealIconColor.opacity(0.2) : Color.white.opacity(0.05), lineWidth: 1)
        }
        .shadow(color: .black.opacity(isExpanded ? 0.1 : 0.05), radius: isExpanded ? 15 : 5, x: 0, y: isExpanded ? 8 : 2)
        .contentShape(Rectangle())
        .onTapGesture { if meal.recipe != nil { onTap() } }
        .redacted(reason: isLoading ? .placeholder : [])
        .opacity(isLoading ? 0.45 : 1)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isExpanded)
        .if(isLoading) { $0.shimmering() }
        .transition(.asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .opacity
        ))
    }

    // MARK: - Meal Header

    private var mealHeader: some View {
        HStack(spacing: 12) {
            // Modern Floating Icon
            ZStack {
                Circle()
                    .fill(mealIconColor.opacity(0.12))
                    .frame(width: 44, height: 44)
                
                Image(systemName: mealIconName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(mealIconColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(localizedMealType)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                
                if let recipe = meal.recipe {
                    HStack(spacing: 8) {
                        Label("\(recipe.calories) kcal", systemImage: "flame.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(SemanticColors.nutrient(.calories))
                        
                        if recipe.estimatedCost > 0 {
                            Label(String(format: "%.2f %@", recipe.estimatedCost, currency), systemImage: "dollarsign.circle.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(SemanticColors.state(.budget))
                        }
                    }
                } else {
                    Text(l10n.t("plan.notPlanned"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if let recipe = meal.recipe {
                HStack(spacing: 12) {
                    if let dish = recipe.sourceDish {
                        favoriteButton(dish: dish)
                    }
                    
                    Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.secondary.opacity(0.3))
                        .symbolEffect(.bounce, value: isExpanded)
                }
            }
        }
    }

    // MARK: - Favorite button

    private func favoriteButton(dish: APIClient.SuggestedDish) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                favVM.toggle(dish)
            }
        } label: {
            ZStack {
                Circle()
                    .fill(favVM.isFavorite(dish.dishName) ? SemanticColors.state(.danger).opacity(0.1) : Color.black.opacity(0.03))
                    .frame(width: 36, height: 36)
                
                Image(systemName: favVM.isFavorite(dish.dishName) ? "heart.fill" : "heart")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(favVM.isFavorite(dish.dishName) ? SemanticColors.state(.danger) : .secondary.opacity(0.5))
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Recipe collapsed row

    @ViewBuilder
    private func recipeRow(_ recipe: Recipe) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Text(recipe.title)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                
                Spacer()
                
                // Action row for quick swap
                Button { onAdd() } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(mealIconColor)
                        .padding(10)
                        .background(mealIconColor.opacity(0.1), in: Circle())
                }
                .buttonStyle(PressButtonStyle())
            }

            if !recipe.dishType.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        tagChip(recipe.dishType, color: SemanticColors.tag(.category))
                        if !recipe.complexity.isEmpty {
                            tagChip(recipe.complexity, color: .secondary)
                        }
                        if !recipe.recipeIngredients.filter({ !$0.available }).isEmpty {
                            tagChip(l10n.t("plan.missingItems"), color: SemanticColors.state(.danger), icon: "cart.fill")
                        }
                    }
                }
            }
        }
    }

    private func tagChip(_ text: String, color: Color, icon: String? = nil) -> some View {
        HStack(spacing: 4) {
            if let icon = icon {
                Image(systemName: icon).font(.system(size: 10, weight: .bold))
            }
            Text(text)
                .font(.system(size: 11, weight: .bold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.1), in: Capsule())
        .foregroundStyle(color)
    }

    // MARK: - Add meal button

    private var addMealButton: some View {
        Button(action: onAdd) {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                Text(l10n.t("plan.addMeal"))
            }
            .appStyle(.bodyMedium)
            .foregroundStyle(SemanticColors.meal(.breakfast).opacity(0.9))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
            .padding(.horizontal, Spacing.sm)
            .surface(.tag(.breakfast), cornerRadius: Radius.xs)
        }
    }

    // MARK: - Meal border overlay

    @ViewBuilder
    private var mealBorder: some View {
        if meal.type == .lunch {
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .strokeBorder(SemanticColors.meal(.breakfast).opacity(0.1), lineWidth: 1)
        }
        if isExpanded {
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .strokeBorder(SemanticColors.meal(.breakfast).opacity(0.15), lineWidth: 1)
        }
    }

    // MARK: - Expanded Detail

    @ViewBuilder
    private func expandedDetail(recipe: Recipe) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Divider().overlay(AppColors.divider)

            // Nutrition strip
            HStack(spacing: 12) {
                nutriPill(icon: "flame.fill",  value: "\(recipe.calories)", unit: l10n.t("plan.kcal"), nutrient: .calories)
                nutriPill(icon: "bolt.fill",   value: "\(recipe.protein)",  unit: l10n.t("plan.gP"),   nutrient: .protein)
                nutriPill(icon: "drop.fill",   value: "\(recipe.fat)",      unit: l10n.t("plan.gF"),   nutrient: .fat)
                nutriPill(icon: "leaf.fill",   value: "\(recipe.carbs)",    unit: l10n.t("plan.gC"),   nutrient: .carbs)
            }

            // Tags
            if !recipe.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(recipe.tags, id: \.self) { tagText in
                            Text(tagText)
                                .appStyle(.tag)
                                .foregroundStyle(SemanticColors.tag(.trend))
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .surface(.tag(.trend), cornerRadius: Radius.full)
                        }
                    }
                }
            }

            // Ingredients list
            ingredientsList(recipe)

            // Missing ingredients
            let missing = recipe.recipeIngredients.filter { !$0.available }
            if !missing.isEmpty {
                missingIngredients(missing)
            }

            // Steps
            if !recipe.richSteps.isEmpty {
                stepsList(recipe)
            }

            // Warnings
            ForEach(recipe.warnings, id: \.self) { w in
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill").font(.caption2)
                        .foregroundStyle(SemanticColors.state(.warning))
                    Text(w).appStyle(.caption)
                        .foregroundStyle(SemanticColors.state(.warning).opacity(0.8))
                }
            }

            // Collapse hint
            HStack(spacing: 4) {
                Spacer()
                Image(systemName: "chevron.up").font(.caption2)
                Text(l10n.t("plan.tapToCollapse")).appStyle(.micro)
                Spacer()
            }
            .foregroundStyle(AppColors.textSecondary.opacity(0.5))
        }
        .padding(.top, 4)
    }

    // MARK: - Ingredients list

    private func ingredientsList(_ recipe: Recipe) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "basket.fill").font(.caption.weight(.semibold))
                    .foregroundStyle(SemanticColors.meal(.breakfast))
                Text(l10n.t("plan.ingredients")).appStyle(.sectionTitle)
                Spacer()
                Text("\(recipe.recipeIngredients.count)").appStyle(.tag)
                    .foregroundStyle(AppColors.textSecondary)
            }

            ForEach(recipe.recipeIngredients) { ing in
                HStack(spacing: 8) {
                    Image(systemName: ing.available ? "checkmark.circle.fill" : "circle.dashed")
                        .font(.caption)
                        .foregroundStyle(ing.available ? SemanticColors.state(.success) : SemanticColors.state(.danger).opacity(0.7))
                    Text(ing.name).appStyle(.caption)
                        .foregroundStyle(ing.available ? AppColors.textPrimary : AppColors.textSecondary)
                    Spacer()
                    Text("\(Int(ing.quantity))g").appStyle(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                    if !ing.role.isEmpty {
                        Text(ing.role).appStyle(.tag)
                            .foregroundStyle(SemanticColors.tag(.category).opacity(0.7))
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .surface(.tag(.category), cornerRadius: Radius.full)
                    }
                }
            }
        }
        .padding(Spacing.sm)
        .surface(.card, cornerRadius: Radius.sm)
    }

    // MARK: - Missing ingredients

    private func missingIngredients(_ missing: [RecipeIngredient]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "cart.badge.plus").font(.caption.weight(.semibold))
                    .foregroundStyle(SemanticColors.state(.danger))
                Text(l10n.t("plan.needToBuy")).appStyle(.sectionTitle)
                Spacer()
                Text("\(missing.count)").appStyle(.tag)
                    .foregroundStyle(AppColors.textPrimary)
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .background(SemanticColors.state(.danger).opacity(0.7), in: Capsule())
            }

            ForEach(missing) { ing in
                HStack(spacing: 8) {
                    Image(systemName: "circle.dashed").font(.caption)
                        .foregroundStyle(SemanticColors.state(.danger).opacity(0.7))
                    Text(ing.name).appStyle(.caption)
                    Spacer()
                    Text("\(Int(ing.quantity))g").appStyle(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
        }
        .padding(Spacing.sm)
        .surface(.card, cornerRadius: Radius.sm)
        .overlay(
            RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                .stroke(SemanticColors.state(.danger).opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Steps

    private func stepsList(_ recipe: Recipe) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "list.number").font(.caption.weight(.semibold))
                    .foregroundStyle(SemanticColors.meal(.breakfast))
                Text(l10n.t("plan.steps")).appStyle(.sectionTitle)
                Spacer()
                Text("\(recipe.richSteps.count) \(l10n.t("plan.stepsCount"))").appStyle(.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }

            ForEach(recipe.richSteps) { step in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(step.id)").appStyle(.tag)
                            .foregroundStyle(SemanticColors.meal(.breakfast))
                            .frame(width: 20, height: 20)
                            .surface(.tag(.breakfast), cornerRadius: Radius.full)
                        Text(step.text).appStyle(.caption)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    HStack(spacing: 8) {
                        if let time = step.timeMin {
                            Label("\(time) min", systemImage: "clock").appStyle(.tag)
                                .foregroundStyle(SemanticColors.tag(.category))
                        }
                        if let temp = step.tempC {
                            Label("\(temp)°C", systemImage: "thermometer.medium").appStyle(.tag)
                                .foregroundStyle(SemanticColors.state(.danger))
                        }
                    }
                    .padding(.leading, 28)

                    if let tip = step.tip, !tip.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "lightbulb.fill").font(.caption2)
                                .foregroundStyle(SemanticColors.state(.warning))
                            Text(tip).appStyle(.caption2)
                                .foregroundStyle(SemanticColors.state(.warning).opacity(0.8))
                        }
                        .padding(.leading, 28)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(Spacing.sm)
        .surface(.card, cornerRadius: Radius.sm)
    }

    // MARK: - Nutrition Pill

    private func nutriPill(icon: String, value: String, unit: String, nutrient: NutrientType) -> some View {
        let c = SemanticColors.nutrient(nutrient)
        return VStack(spacing: 3) {
            Image(systemName: icon).font(.caption2).foregroundStyle(c)
            Text(value).appStyle(.nutrientValue).foregroundStyle(AppColors.textPrimary)
            Text(unit).font(.system(size: 9)).foregroundStyle(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .surface(.tag(nutrient.tagStyle), cornerRadius: Radius.xs)
    }

    // MARK: - Helpers

    private var localizedMealType: String {
        switch meal.type {
        case .breakfast: return l10n.t("plan.breakfast")
        case .lunch:     return l10n.t("plan.lunch")
        case .dinner:    return l10n.t("plan.dinner")
        }
    }

    private var mealTagStyle: TagStyle {
        switch meal.type {
        case .breakfast: return .breakfast
        case .lunch:     return .lunch
        case .dinner:    return .dinner
        }
    }

    private var mealIconName: String {
        switch meal.type {
        case .breakfast: return "sunrise.fill"
        case .lunch:     return "sun.max.fill"
        case .dinner:    return "moon.stars.fill"
        }
    }

    private var mealIconColor: Color {
        switch meal.type {
        case .breakfast: return .orange
        case .lunch:     return .orange
        case .dinner:    return .purple
        }
    }
}

// MARK: - NutrientType → TagStyle bridge
// Keeps the color mapping DRY: TagStyle.color already knows each nutrient's color.

private extension NutrientType {
    var tagStyle: TagStyle {
        switch self {
        case .calories: return .calories
        case .protein:  return .protein
        case .fat:      return .fat
        case .carbs:    return .carbs
        }
    }
}
