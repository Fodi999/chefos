
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
        VStack(alignment: .leading, spacing: 10) {
            mealHeader
            if let recipe = meal.recipe {
                Divider().overlay(AppColors.divider)
                recipeRow(recipe)
                if isExpanded {
                    expandedDetail(recipe: recipe)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            } else {
                addMealButton
            }
        }
        .padding(meal.type == .lunch ? Spacing.md : 14)
        .surface(.card, cornerRadius: Radius.md)
        .opacity(meal.type == .dinner ? 0.85 : 1.0)
        .overlay { mealBorder }
        .contentShape(Rectangle())
        .onTapGesture { if meal.recipe != nil { onTap() } }
        .redacted(reason: isLoading ? .placeholder : [])
        .opacity(isLoading ? 0.45 : 1)
        .animation(.easeInOut(duration: 0.4), value: isLoading)
        .if(isLoading) { $0.shimmering() }
        .transition(.asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .opacity
        ))
    }

    // MARK: - Meal Header

    private var mealHeader: some View {
        HStack {
            // Meal type icon
            Image(systemName: mealIconName)
                .font(meal.type == .lunch ? .title2 : .title3)
                .foregroundStyle(mealIconColor)
                .frame(width: meal.type == .lunch ? 40 : 36,
                       height: meal.type == .lunch ? 40 : 36)
                .surface(.tag(mealTagStyle),
                         cornerRadius: meal.type == .lunch ? Radius.sm : Radius.xs)

            // Meal type label
            VStack(alignment: .leading, spacing: 1) {
                Text(localizedMealType)
                    .font(meal.type == .lunch ? .headline.weight(.bold) : .subheadline.weight(.semibold))
                if meal.type == .lunch && meal.recipe != nil {
                    Text(l10n.t("plan.mainMeal"))
                        .appStyle(.tag)
                        .foregroundStyle(SemanticColors.meal(.breakfast).opacity(0.8))
                }
            }

            Spacer()

            // Recipe badges
            if let recipe = meal.recipe {
                if let dish = recipe.sourceDish {
                    favoriteButton(dish: dish)
                }
                recipeBadges(recipe)
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
            Image(systemName: favVM.isFavorite(dish.dishName) ? "heart.fill" : "heart")
                .font(.body)
                .foregroundStyle(favVM.isFavorite(dish.dishName) ? SemanticColors.state(.danger) : AppColors.textSecondary.opacity(0.5))
                .symbolEffect(.bounce, value: favVM.isFavorite(dish.dishName))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Recipe badges (kcal / cost / missing)

    private func recipeBadges(_ recipe: Recipe) -> some View {
        HStack(spacing: 6) {
            Text("\(recipe.calories) kcal")
                .appStyle(.tag)
                .foregroundStyle(SemanticColors.nutrient(.calories))
                .padding(.horizontal, 8).padding(.vertical, 4)
                .surface(.tag(.calories), cornerRadius: Radius.full)

            if recipe.estimatedCost > 0 {
                Text(String(format: "%.2f %@", recipe.estimatedCost, currency))
                    .appStyle(.tag)
                    .foregroundStyle(SemanticColors.state(.budget))
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .surface(.tag(.budget), cornerRadius: Radius.full)
            }
            if !recipe.recipeIngredients.filter({ !$0.available }).isEmpty {
                Image(systemName: "cart.badge.plus")
                    .font(.caption2)
                    .foregroundStyle(SemanticColors.state(.danger))
                    .padding(4)
                    .surface(.tag(.danger), cornerRadius: Radius.full)
            }
        }
    }

    // MARK: - Recipe collapsed row

    @ViewBuilder
    private func recipeRow(_ recipe: Recipe) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(recipe.title)
                    .appStyle(.bodyMedium)

                if !recipe.dishType.isEmpty {
                    HStack(spacing: 6) {
                        Text(recipe.dishType)
                            .appStyle(.tag)
                            .foregroundStyle(SemanticColors.tag(.category))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .surface(.tag(.category), cornerRadius: Radius.full)

                        if !recipe.complexity.isEmpty {
                            Text(recipe.complexity)
                                .appStyle(.caption)
                                .foregroundStyle(AppColors.textSecondary)
                        }
                    }
                } else {
                    Text(recipe.ingredients.prefix(3).joined(separator: " · "))
                        .appStyle(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            HStack(spacing: 8) {
                Button { onAdd() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.2.circlepath").font(.caption2.weight(.bold))
                        Text(l10n.t("plan.replace")).appStyle(.tag)
                    }
                }
                .buttonStyle(.bordered)
                .tint(SemanticColors.meal(.breakfast))
                .controlSize(.small)

                Button { onClear() } label: {
                    Image(systemName: "xmark").font(.caption2.weight(.medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppColors.textSecondary.opacity(0.35))
            }
        }

        if !isExpanded {
            HStack(spacing: 4) {
                Image(systemName: "chevron.down").font(.caption2)
                Text(l10n.t("plan.tapToExpand")).appStyle(.micro)
            }
            .foregroundStyle(AppColors.textSecondary.opacity(0.5))
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 2)
        }
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
