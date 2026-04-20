import SwiftUI

struct CookingCompleteSheet: View {
    let dish: APIClient.SuggestedDish
    @EnvironmentObject var l10n: LocalizationService
    @Environment(\.dismiss) private var dismiss
    @State private var deducting = false
    @State private var deducted = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                // Celebration
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.green)
                    .symbolEffect(.bounce, value: deducted)

                Text(l10n.t("cook.cookingComplete"))
                    .font(.title.weight(.bold))

                Text(dish.displayName ?? dish.dishNameLocal ?? dish.dishName)
                    .font(.title3).foregroundStyle(.secondary)

                // Nutrition summary
                HStack(spacing: 16) {
                    nutritionBadge("🔥", "\(dish.perServingKcal)", l10n.t("cook.kcal"))
                    nutritionBadge("🥩", String(format: "%.0f", dish.perServingProteinG), l10n.t("cook.protein"))
                    nutritionBadge("🧈", String(format: "%.0f", dish.perServingFatG), l10n.t("cook.fat"))
                    nutritionBadge("🍞", String(format: "%.0f", dish.perServingCarbsG), l10n.t("cook.carbs"))
                }
                .padding(16)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))

                if deducted {
                    HStack(spacing: 8) {
                        Image(systemName: "tray.full.fill").foregroundStyle(.green)
                        Text(l10n.t("cook.ingredientsDeducted")).font(.subheadline)
                    }
                    .padding(12)
                    .background(Color.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                }

                if let error {
                    Text(error).font(.caption).foregroundStyle(.red).padding(.horizontal)
                }

                Spacer()

                // Deduct button
                if !deducted {
                    Button {
                        Task { await deductIngredients() }
                    } label: {
                        HStack(spacing: 8) {
                            if deducting {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                            }
                            Text(l10n.t("cook.confirmAndDeduct"))
                                .font(.headline.weight(.bold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.green, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .disabled(deducting)
                    .padding(.horizontal)

                    Button { dismiss() } label: {
                        Text(l10n.t("cook.skipDeduction"))
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                } else {
                    Button {
                        dismiss()
                    } label: {
                        Text(l10n.t("cook.done"))
                            .font(.headline.weight(.bold)).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 16)
                            .background(Color.blue, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .padding(.horizontal)
                }

                Color.clear.frame(height: 20)
            }
            .background(LinearGradient.screenBackground.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func nutritionBadge(_ emoji: String, _ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(emoji)
            Text(value).font(.headline.weight(.bold))
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity)
    }

    private func deductIngredients() async {
        deducting = true
        error = nil
        let api = APIClient.shared

        // Delete available ingredients that have a productId
        for ingredient in dish.ingredients where ingredient.available {
            if let productId = ingredient.productId {
                do {
                    try await api.deleteInventoryProduct(id: productId)
                } catch {
                    // Continue even on error — some may already be deleted
                    print("Failed to deduct \(ingredient.name): \(error)")
                }
            }
        }

        await MainActor.run {
            deducting = false
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                deducted = true
            }
        }
    }
}
