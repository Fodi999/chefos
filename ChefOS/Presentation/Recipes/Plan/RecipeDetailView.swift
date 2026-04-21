// MARK: - Presentation/Recipes/Plan/RecipeDetailView.swift
// Extracted from RecipesView.swift as part of DDD refactoring

import SwiftUI

struct RecipeDetailView: View {
    let recipe: Recipe
    @ObservedObject var viewModel: RecipesViewModel
    var planViewModel: PlanViewModel?
    var currency: String = "$"
    @State private var showMealPicker = false
    @EnvironmentObject var l10n: LocalizationService

    private var missing: [String] { viewModel.missingIngredients(for: recipe) }
    private var canCookNow: Bool { viewModel.canCook(recipe) }

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerCard
                    ingredientsCard
                    actionButtons
                    stepsCard
                }
                .padding()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppColors.surface, for: .navigationBar)
        .sheet(isPresented: $showMealPicker) {
            if let pvm = planViewModel {
                MealSlotPicker(recipe: recipe, planViewModel: pvm)
                    .presentationDetents([.height(280)])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: - Header Card

    private var headerCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "fork.knife.circle.fill")
                .font(.system(size: 50)).foregroundStyle(.orange)
            Text(recipe.title).font(.title.bold()).multilineTextAlignment(.center)
            HStack(spacing: 16) {
                Label("\(recipe.calories) kcal", systemImage: "flame.fill")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(.orange)
                Label("\(recipe.protein)g", systemImage: "bolt.fill")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(.cyan)
                Label("\(recipe.servings) \(l10n.t("recipes.servings"))", systemImage: "person.2.fill")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(.purple)
            }
            HStack(spacing: 20) {
                economyCell(value: String(format: "%.2f %@", recipe.estimatedCost, currency),
                            label: l10n.t("recipes.totalCost"))
                Divider().frame(height: 30).overlay(Color.white.opacity(0.06))
                economyCell(value: String(format: "%.2f %@", recipe.costPerServing, currency),
                            label: l10n.t("recipes.portion"))
                Divider().frame(height: 30).overlay(Color.white.opacity(0.06))
                let pct = viewModel.budgetPercent(for: recipe)
                economyCell(value: "\(pct)%",
                            label: l10n.t("recipes.ofBudget"),
                            valueColor: pct <= 15 ? .green : pct <= 30 ? .orange : .red)
            }
            .padding(.vertical, 12).padding(.horizontal, 16)
            .background(AppColors.surfaceRaised, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            HStack(spacing: 6) {
                Image(systemName: canCookNow ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                Text(canCookNow ? l10n.t("recipes.allInStock") : "\(l10n.t("recipes.missing")) \(missing.count)")
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(canCookNow ? .green : .orange)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 20).productCard(cornerRadius: 24)
    }

    private func economyCell(value: String, label: String, valueColor: Color = .green) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.headline.weight(.bold)).foregroundStyle(valueColor)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }

    // MARK: - Ingredients Card

    private var ingredientsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(l10n.t("recipes.ingredients"), systemImage: "basket.fill")
                .font(.title3.bold()).foregroundStyle(.primary)
            ForEach(viewModel.ingredientStatus(for: recipe), id: \.id) { s in
                HStack(spacing: 10) {
                    Image(systemName: s.inStock ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.caption).foregroundStyle(s.inStock ? .green : .red)
                    Text(s.name).foregroundStyle(s.inStock ? Color.primary : Color.secondary)
                    Spacer()
                    Text(s.qty).font(.subheadline.weight(.semibold))
                        .foregroundStyle(s.inStock ? Color.primary : Color.red)
                    Text(s.inStock ? "OK" : l10n.t("recipes.missing"))
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(s.inStock ? .green : .red)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background((s.inStock ? Color.green : Color.red).opacity(0.1), in: Capsule())
                }
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).productCard(cornerRadius: 20)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 12) {
            if canCookNow {
                Button {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { viewModel.cookRecipe(recipe) }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "flame.fill")
                        Text(l10n.t("recipes.cookNow")).font(.headline.weight(.bold))
                    }
                    .foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(Color.orange, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }.buttonStyle(PressButtonStyle())

                Button { showMealPicker = true } label: {
                    HStack(spacing: 6) {
                        if let slot = planViewModel?.plannedSlot(for: recipe) {
                            Image(systemName: "checkmark.circle.fill")
                            Text(slot).font(.headline.weight(.bold))
                        } else {
                            Image(systemName: "calendar.badge.plus")
                            Text(l10n.t("recipes.plan")).font(.headline.weight(.bold))
                        }
                    }
                    .foregroundStyle(planViewModel?.plannedSlot(for: recipe) != nil ? .cyan : .secondary)
                    .padding(.vertical, 14).padding(.horizontal, 24)
                    .background(AppColors.surfaceRaised, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.04), lineWidth: 1))
                }.buttonStyle(PressButtonStyle())
            } else {
                Button { viewModel.addToShoppingList(recipe: recipe) } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "cart.badge.plus")
                        Text(l10n.t("recipes.addMissingShopping")).font(.headline.weight(.bold))
                    }
                    .foregroundStyle(.orange).frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.orange.opacity(0.15), lineWidth: 1))
                }.buttonStyle(PressButtonStyle())
            }
        }
    }

    // MARK: - Steps Card

    private var stepsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(l10n.t("recipes.steps"), systemImage: "list.number")
                .font(.title3.bold()).foregroundStyle(.primary)
            ForEach(Array(recipe.steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(index + 1)").font(.caption.bold()).foregroundStyle(.white)
                        .frame(width: 24, height: 24)
                        .background(Color.orange, in: Circle())
                    Text(step).foregroundStyle(.primary)
                }
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).productCard(cornerRadius: 20)
    }
}
