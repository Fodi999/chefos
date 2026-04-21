// MARK: - Presentation/Recipes/Plan/CookRecipeRow.swift
// Extracted from RecipesView.swift as part of DDD refactoring

import SwiftUI

struct CookRecipeRow: View {
    let recipe: Recipe
    let canCook: Bool
    @ObservedObject var viewModel: RecipesViewModel
    var planViewModel: PlanViewModel?
    var onAddToPlan: (() -> Void)? = nil
    var currency: String = "$"
    @State private var expanded = false
    @EnvironmentObject var l10n: LocalizationService

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(canCook ? Color.green : Color.orange)
                        .frame(width: 50, height: 50)
                    Image(systemName: canCook ? "checkmark.seal.fill" : "fork.knife")
                        .font(.title3).foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(recipe.title).font(.headline).foregroundStyle(.primary)

                    HStack(spacing: 8) {
                        if canCook {
                            HStack(spacing: 3) {
                                Image(systemName: "checkmark.circle.fill").font(.caption2).foregroundStyle(.green)
                                Text(l10n.t("recipes.canCook")).font(.caption.weight(.semibold)).foregroundStyle(.green)
                            }
                        } else {
                            let missing = viewModel.missingIngredients(for: recipe)
                            HStack(spacing: 3) {
                                Image(systemName: "exclamationmark.triangle.fill").font(.caption2).foregroundStyle(.orange)
                                Text("\(l10n.t("recipes.missing")) \(missing.count)").font(.caption.weight(.semibold)).foregroundStyle(.orange)
                            }
                        }
                        if let slot = planViewModel?.plannedSlot(for: recipe) {
                            HStack(spacing: 3) {
                                Image(systemName: "calendar.badge.checkmark").font(.caption2).foregroundStyle(.cyan)
                                Text(slot).font(.caption2.weight(.bold)).foregroundStyle(.cyan)
                            }
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(.cyan.opacity(0.12), in: Capsule())
                        }
                    }

                    HStack(spacing: 8) {
                        HStack(spacing: 3) {
                            Image(systemName: "banknote.fill").font(.caption2).foregroundStyle(.secondary)
                            Text("\(String(format: "%.2f %@", recipe.costPerServing, currency)) \(l10n.t("recipes.portion"))")
                                .font(.caption2.weight(.medium)).foregroundStyle(.secondary)
                        }
                        HStack(spacing: 3) {
                            Image(systemName: "bolt.fill").font(.caption2).foregroundStyle(.secondary)
                            Text("\(recipe.calories) kcal").font(.caption2.weight(.medium)).foregroundStyle(.secondary)
                        }
                        let tag = viewModel.priceTag(for: recipe)
                        Text(tag.label).font(.caption2.weight(.bold)).foregroundStyle(tag.color)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(tag.color.opacity(0.12), in: Capsule())
                    }
                }

                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }

            let statuses = viewModel.ingredientStatus(for: recipe)
            if !statuses.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Button {
                        withAnimation(.snappy(duration: 0.3)) { expanded.toggle() }
                    } label: {
                        HStack(spacing: 4) {
                            Text(expanded ? l10n.t("recipes.hideIngredients") : l10n.t("recipes.showIngredients"))
                                .font(.caption2.weight(.bold)).foregroundStyle(.secondary)
                            Image(systemName: expanded ? "chevron.up" : "chevron.down")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    if expanded {
                        ForEach(Array(statuses)) { s in
                            HStack(spacing: 6) {
                                Image(systemName: s.inStock ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .font(.caption2).foregroundStyle(s.inStock ? .green : .red)
                                Text("\(s.name) \(s.qty)").font(.caption2)
                                    .foregroundStyle(s.inStock ? .primary : .secondary)
                                if s.inStock { Text("(OK)").font(.caption2).foregroundStyle(.green.opacity(0.7)) }
                            }
                        }
                    }
                }
                .padding(.leading, 64)
            }

            HStack(spacing: 10) {
                if canCook {
                    Button {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { viewModel.cookRecipe(recipe) }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "flame.fill").font(.caption2)
                            Text(l10n.t("recipes.cookBtn")).font(.caption.weight(.bold))
                        }
                        .foregroundStyle(.white).padding(.horizontal, 16).padding(.vertical, 8)
                        .background(Color.orange, in: Capsule())
                    }.buttonStyle(PressButtonStyle())

                    Button { onAddToPlan?() } label: {
                        HStack(spacing: 5) {
                            if planViewModel?.plannedSlot(for: recipe) != nil {
                                Image(systemName: "checkmark.circle.fill").font(.caption2)
                                Text(l10n.t("recipes.added")).font(.caption.weight(.bold))
                            } else {
                                Image(systemName: "calendar.badge.plus").font(.caption2)
                                Text(l10n.t("recipes.addToPlan")).font(.caption.weight(.bold))
                            }
                        }
                        .foregroundStyle(planViewModel?.plannedSlot(for: recipe) != nil ? .cyan : .secondary)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(AppColors.surfaceRaised, in: Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.04), lineWidth: 1))
                    }
                    .buttonStyle(PressButtonStyle())
                    .disabled(planViewModel?.plannedSlot(for: recipe) != nil)
                } else {
                    Button { viewModel.addToShoppingList(recipe: recipe) } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "cart.badge.plus").font(.caption2)
                            Text(l10n.t("recipes.addShopping")).font(.caption.weight(.bold))
                        }
                        .foregroundStyle(.orange).padding(.horizontal, 16).padding(.vertical, 8)
                        .background(.orange.opacity(0.08), in: Capsule())
                        .overlay(Capsule().stroke(Color.orange.opacity(0.15), lineWidth: 1))
                    }.buttonStyle(PressButtonStyle())
                }
                Spacer()
            }
            .padding(.leading, 64)
        }
        .padding(14)
        .surface(.card, cornerRadius: 18)
        .overlay {
            if canCook {
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(Color.green.opacity(0.15), lineWidth: 1)
            }
        }
        .opacity(viewModel.cookedRecipeId == recipe.id ? 0.3 : 1.0)
        .scaleEffect(viewModel.cookedRecipeId == recipe.id ? 0.97 : 1.0)
        .animation(.easeOut(duration: 0.4), value: viewModel.cookedRecipeId)
    }
}
