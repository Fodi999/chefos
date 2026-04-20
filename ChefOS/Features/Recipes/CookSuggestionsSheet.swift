import SwiftUI

struct CookSuggestionsSheet: View {
    @ObservedObject var vm: CookSuggestionsViewModel
    @EnvironmentObject var l10n: LocalizationService
    @EnvironmentObject var regionService: RegionService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient.screenBackground
                    .ignoresSafeArea()

                if vm.isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text(l10n.t("cook.analyzing"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else if let error = vm.errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundStyle(.orange)
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button(l10n.t("cook.retry")) {
                            Task { await vm.loadSuggestions() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else if vm.isEmpty && vm.hasLoaded {
                    VStack(spacing: 12) {
                        Image(systemName: "basket")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text(l10n.t("cook.empty"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            if !vm.canCook.isEmpty {
                                dishSection(
                                    title: l10n.t("cook.canCookNow"),
                                    icon: "checkmark.circle.fill",
                                    color: .green,
                                    dishes: vm.canCook
                                )
                            }
                            if !vm.almost.isEmpty {
                                dishSection(
                                    title: l10n.t("cook.almostReady"),
                                    icon: "minus.circle.fill",
                                    color: .orange,
                                    dishes: vm.almost
                                )
                            }
                            if !vm.strategic.isEmpty {
                                dishSection(
                                    title: l10n.t("cook.strategic"),
                                    icon: "brain.head.profile",
                                    color: .purple,
                                    dishes: vm.strategic
                                )
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle(l10n.t("cook.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Section

    @ViewBuilder
    private func dishSection(title: String, icon: String, color: Color, dishes: [APIClient.SuggestedDish]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(.headline.weight(.bold))
                Spacer()
                Text("\(dishes.count)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(color.opacity(0.8), in: Capsule())
            }

            ForEach(dishes) { dish in
                dishCard(dish, accentColor: color)
            }
        }
    }

    // MARK: - Dish Card

    @ViewBuilder
    private func dishCard(_ dish: APIClient.SuggestedDish, accentColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(dish.dishNameLocal ?? dish.dishName)
                        .font(.subheadline.weight(.bold))
                    if let local = dish.dishNameLocal, local != dish.dishName {
                        Text(dish.dishName)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                // Insight badges
                HStack(spacing: 4) {
                    if dish.insight.usesExpiring {
                        insightBadge("⏰", color: .orange)
                    }
                    if dish.insight.highProtein {
                        insightBadge("💪", color: .blue)
                    }
                    if dish.insight.budgetFriendly {
                        insightBadge("💰", color: .green)
                    }
                }
            }

            // Nutrition row
            HStack(spacing: 12) {
                nutritionPill("🔥", "\(dish.totalKcal)")
                nutritionPill("P", String(format: "%.0fg", dish.totalProteinG))
                nutritionPill("F", String(format: "%.0fg", dish.totalFatG))
                nutritionPill("C", String(format: "%.0fg", dish.totalCarbsG))
                Spacer()
                Text("🍽 \(dish.servings)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            // Ingredients
            let available = dish.ingredients.filter { $0.available }
            let missing = dish.missingIngredients

            if !available.isEmpty {
                FlowLayout(spacing: 4) {
                    ForEach(available, id: \.slug) { ing in
                        Text(ing.name)
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                ing.expiringSoon
                                    ? Color.orange.opacity(0.2)
                                    : Color.green.opacity(0.15),
                                in: Capsule()
                            )
                            .foregroundStyle(ing.expiringSoon ? .orange : .green)
                    }
                }
            }

            if !missing.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "cart.badge.plus")
                        .font(.caption2)
                        .foregroundStyle(.red.opacity(0.7))
                    Text(missing.joined(separator: ", "))
                        .font(.caption2)
                        .foregroundStyle(.red.opacity(0.8))
                }
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(accentColor.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Helpers

    private func insightBadge(_ emoji: String, color: Color) -> some View {
        Text(emoji)
            .font(.caption)
            .padding(4)
            .background(color.opacity(0.15), in: Circle())
    }

    private func nutritionPill(_ label: String, _ value: String) -> some View {
        HStack(spacing: 2) {
            Text(label)
                .font(.caption2.weight(.bold))
            Text(value)
                .font(.caption2)
        }
        .foregroundStyle(.secondary)
    }
}
