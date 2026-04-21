// MARK: - Presentation/Recipes/Plan/MealSlotPicker.swift
// Extracted from RecipesView.swift as part of DDD refactoring

import SwiftUI

struct MealSlotPicker: View {
    let recipe: Recipe
    @ObservedObject var planViewModel: PlanViewModel
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var l10n: LocalizationService

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 6) {
                Image(systemName: "calendar.badge.plus").font(.title2).foregroundStyle(.orange)
                Text(l10n.t("recipes.addToPlan")).font(.headline.weight(.bold))
                Text(recipe.title).font(.subheadline).foregroundStyle(.secondary)
            }.padding(.top, 8)

            VStack(spacing: 10) {
                ForEach(Meal.MealType.allCases, id: \.self) { type in
                    let isFilled = !(planViewModel.emptySlots.contains { $0.type == type })
                        && planViewModel.weekDays.indices.contains(planViewModel.selectedDayIndex)
                        && planViewModel.weekDays[planViewModel.selectedDayIndex].meals.contains { $0.type == type && $0.recipe != nil }

                    Button {
                        planViewModel.addRecipeToPlan(recipe, mealType: type)
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: mealIcon(type))
                                .font(.body.weight(.semibold)).foregroundStyle(mealColor(type)).frame(width: 32)
                            Text(type.rawValue).font(.subheadline.weight(.semibold))
                            Spacer()
                            Text(isFilled ? l10n.t("recipes.replace") : l10n.t("recipes.empty"))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(isFilled ? .orange : .green)
                        }
                        .padding(14)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.white.opacity(0.06), lineWidth: 1))
                    }.buttonStyle(PressButtonStyle())
                }
            }.padding(.horizontal)

            Spacer()
        }
        .presentationBackground(.ultraThinMaterial)
    }

    private func mealIcon(_ type: Meal.MealType) -> String {
        switch type {
        case .breakfast: return "sunrise.fill"
        case .lunch:     return "sun.max.fill"
        case .dinner:    return "moon.stars.fill"
        }
    }

    private func mealColor(_ type: Meal.MealType) -> Color {
        switch type {
        case .breakfast: return .orange
        case .lunch:     return .yellow
        case .dinner:    return .indigo
        }
    }
}
