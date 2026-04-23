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

    /// Ingredient whose Wikipedia-style detail is currently being shown.
    @State private var detailIngredient: APIClient.CatalogIngredientDTO?

    // Number editor sheets
    @State private var showQuantityEditor = false
    @State private var showPriceEditor    = false
    @State private var showShelfLifeEditor = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()

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
                    .background(AppColors.surfaceRaised, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.white.opacity(0.04), lineWidth: 1))
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
        .sheet(item: $detailIngredient) { ing in
            IngredientDetailSheet(
                slug: ing.id,                 // backend accepts UUID or slug
                fallbackName: ing.name,
                fallbackImageUrl: ing.imageUrl
            )
            .environmentObject(l10n)
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
                        Capsule().fill(AppColors.surfaceRaised)
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
                .scrollIndicators(.hidden)
            }
        }
    }

    private func ingredientRow(_ ingredient: APIClient.CatalogIngredientDTO) -> some View {
        Button {
            withAnimation(.snappy(duration: 0.3)) {
                vm.primeAddForm(for: ingredient)
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

                // "Show full data" — opens Wikipedia-style detail sheet.
                Button {
                    detailIngredient = ingredient
                } label: {
                    Image(systemName: "info.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 4)

                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.green)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(AppColors.surfaceRaised, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.white.opacity(0.04), lineWidth: 1))
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
                .productCard(cornerRadius: 16)

                // ── Quantity picker (iOS 26 decimal wheel, Apple Health style) ──
                VStack(spacing: 10) {
                    DecimalPickerRow(
                        label: l10n.t("recipes.quantity"),
                        value: Double(vm.addQuantity) ?? 0,
                        unit: ingredient.defaultUnit,
                        icon: "scalemass.fill",
                        fractionDigits: 2
                    ) { showQuantityEditor = true }
                    .sheet(isPresented: $showQuantityEditor) {
                        DecimalPickerSheet(
                            title: l10n.t("recipes.quantity"),
                            unit: ingredient.defaultUnit,
                            wholeRange: 0...9999,
                            fractionSlots: 100,
                            initial: Double(vm.addQuantity) ?? 1
                        ) { v in
                            // Keep whole numbers clean, otherwise 2 decimals
                            vm.addQuantity = v == v.rounded() ? "\(Int(v))" : String(format: "%.2f", v)
                        }
                    }

                    if let cal = ingredient.caloriesPer100g,
                       let qty = Double(vm.addQuantity), qty > 0 {
                        HStack {
                            Image(systemName: "flame.fill")
                                .foregroundStyle(.orange)
                                .font(.caption)
                            Text("≈ \(Int(qty * cal / 100)) kcal")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.orange)
                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .padding(.bottom, 6)
                        .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .leading)))
                    }
                }
                .productCard(cornerRadius: 16)
                .animation(.snappy(duration: 0.2), value: vm.addQuantity)

                // Price + dates + shelf life
                VStack(spacing: 0) {
                    Text(l10n.t("recipes.yourSettings"))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14)
                        .padding(.top, 12)
                        .padding(.bottom, 6)

                    // Price — decimal wheel
                    DecimalPickerRow(
                        label: l10n.t("recipes.price"),
                        value: Double(vm.addPrice) ?? 0,
                        unit: currencySymbol,
                        icon: "banknote.fill",
                        fractionDigits: 2
                    ) { showPriceEditor = true }
                    .sheet(isPresented: $showPriceEditor) {
                        DecimalPickerSheet(
                            title: l10n.t("recipes.price"),
                            unit: currencySymbol,
                            wholeRange: 0...99999,
                            fractionSlots: 100,
                            initial: Double(vm.addPrice) ?? 0
                        ) { v in
                            vm.addPrice = String(format: "%.2f", v)
                        }
                    }

                    Divider().overlay(Color.white.opacity(0.05)).padding(.leading, 14)

                    // Shelf-life picker (days)
                    NumberPickerRow(
                        label: l10n.t("recipes.shelfLife"),
                        value: Int(vm.addExpiryDays) ?? 7,
                        unit: l10n.t("recipes.days")
                    ) { showShelfLifeEditor = true }
                    .sheet(isPresented: $showShelfLifeEditor) {
                        NumberPickerSheet(
                            title: l10n.t("recipes.shelfLife"),
                            unit: l10n.t("recipes.days"),
                            range: 1...365,
                            initial: Int(vm.addExpiryDays) ?? 7
                        ) { v in
                            vm.addExpiryDays = "\(v)"
                            vm.syncExpiryFromDays()
                        }
                    }

                    // Quick shelf chips
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach([1, 3, 7, 14, 30, 90], id: \.self) { d in
                                shelfChip(days: d)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.bottom, 10)
                    }

                    Divider().overlay(Color.white.opacity(0.05)).padding(.leading, 14)

                    dateField(
                        title: l10n.t("recipes.purchaseDate"),
                        icon: "calendar",
                        date: $vm.addPurchaseDate,
                        range: ...Date()
                    )
                    .onChange(of: vm.addPurchaseDate) { _, _ in vm.syncExpiryFromDays() }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)

                    Divider().overlay(Color.white.opacity(0.05)).padding(.leading, 14)

                    dateField(
                        title: l10n.t("recipes.expiryDate"),
                        icon: "calendar.badge.exclamationmark",
                        date: $vm.addExpiryDate,
                        range: vm.addPurchaseDate...
                    )
                    .onChange(of: vm.addExpiryDate) { _, _ in vm.syncDaysFromExpiry() }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                }
                .productCard(cornerRadius: 16)

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
                    .background(Color.green, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .animation(.snappy, value: vm.showSuccessBanner)
                }
                .disabled(vm.isSaving || vm.addQuantity.isEmpty)
                .opacity((vm.isSaving || vm.addQuantity.isEmpty) ? 0.5 : 1)

                if vm.showLoginRequired {
                    loginRequiredCard
                }

                if let error = vm.error {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .padding()
        }
    }

    // MARK: - Numpad input handler

    private func numpadTap(_ key: String) {
        switch key {
        case "⌫":
            if !vm.addQuantity.isEmpty { vm.addQuantity.removeLast() }
        case ".":
            guard !vm.addQuantity.contains(".") else { return }
            if vm.addQuantity.isEmpty { vm.addQuantity = "0." } else { vm.addQuantity += "." }
        default:
            // Don't allow leading zero before digits (except "0.")
            if vm.addQuantity == "0" { vm.addQuantity = key; return }
            // Limit total length
            guard vm.addQuantity.count < 7 else { return }
            vm.addQuantity += key
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

    // MARK: - Date field (native DatePicker aligned with formField look)

    @ViewBuilder
    private func dateField(
        title: String,
        icon: String,
        date: Binding<Date>,
        range: PartialRangeThrough<Date>
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            DatePicker(
                "",
                selection: date,
                in: range,
                displayedComponents: .date
            )
            .labelsHidden()
            .datePickerStyle(.compact)
        }
    }

    @ViewBuilder
    private func dateField(
        title: String,
        icon: String,
        date: Binding<Date>,
        range: PartialRangeFrom<Date>
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            DatePicker(
                "",
                selection: date,
                in: range,
                displayedComponents: .date
            )
            .labelsHidden()
            .datePickerStyle(.compact)
        }
    }

    // MARK: - Shelf-life quick chip

    private func shelfChip(days: Int) -> some View {
        let isActive = (Int(vm.addExpiryDays) ?? -1) == days
        return Button {
            vm.setShelfLifeDays(days)
        } label: {
            Text("+\(days) \(l10n.t("recipes.days"))")
                .font(.caption.weight(.semibold))
                .foregroundStyle(isActive ? .white : .secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background {
                    if isActive {
                        Capsule().fill(Color.green.opacity(0.7))
                    } else {
                        Capsule().fill(AppColors.surfaceRaised)
                    }
                }
                .overlay(Capsule().stroke(Color.white.opacity(isActive ? 0 : 0.06), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Login-required card

    /// Shown inline under the "Add to stock" button when the user tries to
    /// save without a backend JWT. Offers a single clear CTA that closes
    /// the sheet — RecipesView owns tab switching, so from there the user
    /// can reach Profile → Sign in.
    private var loginRequiredCard: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "person.crop.circle.badge.exclamationmark")
                    .font(.title3)
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text(l10n.t("auth.loginRequiredTitle"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text(l10n.t("auth.loginRequiredBody"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
            Button {
                vm.showLoginRequired = false
                dismiss()
            } label: {
                Text(l10n.t("auth.signIn"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.orange, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.orange.opacity(0.3), lineWidth: 1))
    }
}
