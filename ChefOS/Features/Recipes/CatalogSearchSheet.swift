//
//  CatalogSearchSheet.swift
//  ChefOS
//

import SwiftUI

struct CatalogSearchSheet: View {
    @ObservedObject var vm: StockViewModel
    @EnvironmentObject var l10n: LocalizationService
    @EnvironmentObject var regionService: RegionService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient.screenBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Search bar
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField(l10n.t("recipes.catalogSearch"), text: $vm.catalogSearch)
                            .textFieldStyle(.plain)
                            .autocorrectionDisabled()
                            .onSubmit { Task { await vm.searchIngredients() } }
                        if !vm.catalogSearch.isEmpty {
                            Button { vm.catalogSearch = ""; Task { await vm.searchIngredients() } } label: {
                                Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(12)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))
                    .padding(.horizontal)
                    .padding(.top, 8)

                    // Category chips
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            categoryChip(id: nil, name: l10n.t("recipes.allCategories"))
                            ForEach(vm.categories) { cat in
                                categoryChip(id: cat.id, name: cat.name)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 10)
                    }

                    Divider().overlay(Color.white.opacity(0.06))

                    // Selected ingredient → add form
                    if let ingredient = vm.selectedIngredient {
                        addForm(ingredient: ingredient)
                    } else {
                        // Results list
                        ingredientsList
                    }
                }
            }
            .navigationTitle(l10n.t("recipes.addProduct"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .task {
                await vm.loadCategories()
                await vm.searchIngredients()
            }
            .onChange(of: vm.catalogSearch) { _, _ in
                Task {
                    try? await Task.sleep(for: .milliseconds(400))
                    await vm.searchIngredients()
                }
            }
        }
    }

    private var currencySymbol: String {
        RegionService.supportedCountries.first { $0.code == regionService.countryCode }?.currencySymbol ?? regionService.currency
    }

    // MARK: - Category Chip

    private func categoryChip(id: String?, name: String) -> some View {
        let isActive = vm.selectedCategoryId == id
        return Button {
            vm.selectedCategoryId = id
            Task { await vm.searchIngredients() }
        } label: {
            Text(name)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isActive ? .white : .secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background {
                    if isActive {
                        Capsule().fill(Color.green.opacity(0.7))
                    } else {
                        Capsule().fill(.ultraThinMaterial)
                    }
                }
                .overlay(Capsule().stroke(Color.white.opacity(isActive ? 0 : 0.06), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Ingredients List

    private var ingredientsList: some View {
        Group {
            if vm.isSearching {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if vm.catalogIngredients.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "carrot")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary.opacity(0.5))
                    Text(l10n.t("recipes.noResults"))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                    Text(l10n.t("recipes.trySearch"))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(vm.catalogIngredients) { ingredient in
                            ingredientRow(ingredient)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
            }
        }
    }

    private func ingredientRow(_ ingredient: APIClient.CatalogIngredientDTO) -> some View {
        Button {
            withAnimation(.snappy(duration: 0.3)) {
                vm.selectedIngredient = ingredient
                vm.addQuantity = "1"
                vm.addExpiryDays = "\(ingredient.defaultShelfLifeDays ?? 7)"
            }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.green.opacity(0.12))
                        .frame(width: 40, height: 40)
                    if let url = ingredient.imageUrl, let imgURL = URL(string: url) {
                        AsyncImage(url: imgURL) { img in
                            img.resizable().scaledToFill()
                        } placeholder: {
                            Image(systemName: "leaf.fill")
                                .foregroundStyle(.green.opacity(0.5))
                        }
                        .frame(width: 32, height: 32)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        Image(systemName: "leaf.fill")
                            .foregroundStyle(.green.opacity(0.5))
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(ingredient.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    HStack(spacing: 8) {
                        Text(ingredient.defaultUnit)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        if let cal = ingredient.caloriesPer100g {
                            Text("\(Int(cal)) \(l10n.t("recipes.calories"))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()

                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.green)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.white.opacity(0.06), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Add Form

    private func addForm(ingredient: APIClient.CatalogIngredientDTO) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                // Ingredient header with real photo
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.green.opacity(0.12))
                            .frame(width: 72, height: 72)
                        if let url = ingredient.imageUrl, let imgURL = URL(string: url) {
                            AsyncImage(url: imgURL) { phase in
                                switch phase {
                                case .success(let img):
                                    img.resizable().scaledToFill()
                                case .failure:
                                    Image(systemName: "leaf.fill")
                                        .font(.title2)
                                        .foregroundStyle(.green.opacity(0.5))
                                default:
                                    ProgressView().tint(.green)
                                }
                            }
                            .frame(width: 64, height: 64)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        } else {
                            Image(systemName: "leaf.fill")
                                .font(.title2)
                                .foregroundStyle(.green.opacity(0.5))
                        }
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text(ingredient.name)
                            .font(.headline.weight(.bold))
                        HStack(spacing: 10) {
                            Label(ingredient.defaultUnit, systemImage: "scalemass")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let cal = ingredient.caloriesPer100g {
                                Label("\(Int(cal)) \(l10n.t("recipes.calories"))", systemImage: "flame")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        }
                        if !ingredient.allergens.isEmpty {
                            Text(ingredient.allergens.joined(separator: ", "))
                                .font(.caption2)
                                .foregroundStyle(.red.opacity(0.7))
                        }
                        if let days = ingredient.defaultShelfLifeDays {
                            Label("\(days) \(l10n.t("recipes.expiryDays"))", systemImage: "clock")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    Spacer()
                    Button {
                        withAnimation(.snappy(duration: 0.3)) {
                            vm.selectedIngredient = nil
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(16)
                .glassCard(cornerRadius: 16)

                // Editable fields — only these are saved to user's inventory
                VStack(spacing: 14) {
                    Text(l10n.t("recipes.yourSettings"))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    formField(title: l10n.t("recipes.quantity"), text: $vm.addQuantity, icon: "number", keyboard: .decimalPad, suffix: ingredient.defaultUnit)
                    formField(title: l10n.t("recipes.price"), text: $vm.addPrice, icon: "banknote", keyboard: .decimalPad, suffix: currencySymbol)
                    formField(title: l10n.t("recipes.expiryDays"), text: $vm.addExpiryDays, icon: "calendar", keyboard: .numberPad, suffix: l10n.t("recipes.days"))
                }
                .padding(16)
                .glassCard(cornerRadius: 16)

                // Add button
                Button {
                    Task { await vm.addProduct() }
                } label: {
                    HStack(spacing: 8) {
                        if vm.isSaving {
                            ProgressView().tint(.white)
                        } else if vm.showSuccessBanner {
                            Image(systemName: "checkmark.circle.fill")
                        } else {
                            Image(systemName: "plus.circle.fill")
                        }
                        Text(vm.isSaving ? l10n.t("recipes.adding") : vm.showSuccessBanner ? "✓" : l10n.t("recipes.addToStock"))
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        (vm.showSuccessBanner ? Color.green : Color.green).gradient,
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
                    .animation(.snappy, value: vm.showSuccessBanner)
                }
                .disabled(vm.isSaving || vm.addQuantity.isEmpty)
                .opacity((vm.isSaving || vm.addQuantity.isEmpty) ? 0.5 : 1)

                if let error = vm.error {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .padding()
        }
    }

    private func formField(title: String, text: Binding<String>, icon: String, keyboard: UIKeyboardType, suffix: String = "") -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            TextField("0", text: text)
                .keyboardType(keyboard)
                .multilineTextAlignment(.trailing)
                .font(.subheadline.weight(.semibold))
                .frame(width: 80)
            if !suffix.isEmpty {
                Text(suffix)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(width: 44, alignment: .leading)
            }
        }
    }
}
