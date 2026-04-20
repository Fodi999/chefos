//
//  InventoryEditorSheet.swift
//  ChefOS
//
//  Reusable sheet for adding a new inventory item or editing an existing one.
//  Covers: "Add to inventory" from quick-add, "Add another batch", "Edit existing".
//

import SwiftUI

// MARK: - Editor Mode

enum InventoryEditorMode {
    /// Brand new product → needs catalog search or manual entry
    case addNew(productName: String)
    /// Add another batch of an existing product (we know the catalogIngredientId)
    case addBatch(productId: String, productName: String, defaultUnit: String)
    /// Edit an existing inventory entry
    case editExisting(item: StockItem)
}

struct InventoryEditorSheet: View {
    let mode: InventoryEditorMode
    @ObservedObject var stockVM: StockViewModel
    @EnvironmentObject var l10n: LocalizationService
    @EnvironmentObject var regionService: RegionService
    @Environment(\.dismiss) private var dismiss

    // Form fields
    @State private var quantity = ""
    @State private var price = ""
    @State private var expiryDays = "7"
    @State private var isSaving = false
    @State private var showSuccess = false
    @State private var errorMessage: String?

    // For addNew mode — catalog search
    @State private var catalogResults: [APIClient.CatalogIngredientDTO] = []
    @State private var selectedIngredient: APIClient.CatalogIngredientDTO?
    @State private var isSearching = false
    @State private var searchText = ""
    @State private var showManualFallback = false

    private var currencySymbol: String {
        RegionService.supportedCountries.first { $0.code == regionService.countryCode }?.currencySymbol ?? regionService.currency
    }

    private var title: String {
        switch mode {
        case .addNew: return l10n.t("inventory.addNew")
        case .addBatch: return l10n.t("inventory.addBatch")
        case .editExisting: return l10n.t("inventory.edit")
        }
    }

    private var productName: String {
        switch mode {
        case .addNew(let name): return name
        case .addBatch(_, let name, _): return name
        case .editExisting(let item): return item.name
        }
    }

    private var unitLabel: String {
        switch mode {
        case .addNew:
            return selectedIngredient?.defaultUnit ?? "kg"
        case .addBatch(_, _, let unit):
            return unit
        case .editExisting(let item):
            return item.unit.displayName
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient.screenBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // Product header
                        productHeader

                        switch mode {
                        case .addNew:
                            addNewContent
                        case .addBatch, .editExisting:
                            inventoryForm
                            saveButton
                        }

                        if let error = errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .padding(.horizontal)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .onAppear { prefill() }
        }
    }

    // MARK: - Product Header

    private var productHeader: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.green.opacity(0.12))
                    .frame(width: 56, height: 56)
                Image(systemName: "leaf.fill")
                    .font(.title3)
                    .foregroundStyle(.green.opacity(0.6))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(productName)
                    .font(.headline.weight(.bold))
                switch mode {
                case .addNew:
                    Text(l10n.t("inventory.searchCatalog"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                case .addBatch:
                    Text(l10n.t("inventory.newBatch"))
                        .font(.caption)
                        .foregroundStyle(.orange)
                case .editExisting:
                    Text(l10n.t("inventory.editCurrent"))
                        .font(.caption)
                        .foregroundStyle(.cyan)
                }
            }
            Spacer()
        }
        .padding(14)
        .glassCard(cornerRadius: 16)
    }

    // MARK: - Add New Content (catalog search → form)

    private var addNewContent: some View {
        VStack(spacing: 16) {
            if let ingredient = selectedIngredient {
                // Catalog match found — show form
                catalogMatchHeader(ingredient)
                inventoryForm
                saveButton
            } else if showManualFallback {
                // No catalog match — manual fallback
                manualFallbackView
            } else {
                // Searching catalog
                catalogSearchView
            }
        }
    }

    private var catalogSearchView: some View {
        VStack(spacing: 12) {
            // Search bar
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField(l10n.t("inventory.searchPlaceholder"), text: $searchText)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    .onSubmit { Task { await searchCatalog() } }
            }
            .padding(12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))

            if isSearching {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else if catalogResults.isEmpty && !searchText.isEmpty {
                // No results — show manual fallback
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.title2)
                        .foregroundStyle(.secondary.opacity(0.5))
                    Text(l10n.t("inventory.noMatch"))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)

                    // Manual fallback buttons
                    manualFallbackButtons
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                // Catalog results
                ForEach(catalogResults) { ingredient in
                    Button {
                        withAnimation(.snappy(duration: 0.3)) {
                            selectedIngredient = ingredient
                            quantity = "1"
                            expiryDays = "\(ingredient.defaultShelfLifeDays ?? 7)"
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
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ingredient.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                                Text(ingredient.defaultUnit)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.green)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .task {
            searchText = productName
            await searchCatalog()
        }
    }

    private func catalogMatchHeader(_ ingredient: APIClient.CatalogIngredientDTO) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 2) {
                Text(ingredient.name)
                    .font(.subheadline.weight(.bold))
                HStack(spacing: 8) {
                    Text(ingredient.defaultUnit)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    if let cal = ingredient.caloriesPer100g {
                        Text("\(Int(cal)) kcal/100g")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
            Button {
                withAnimation(.snappy(duration: 0.3)) {
                    selectedIngredient = nil
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Color.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.green.opacity(0.2), lineWidth: 1))
    }

    // MARK: - Manual Fallback

    private var manualFallbackView: some View {
        VStack(spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text(String(format: l10n.t("inventory.notInCatalog"), productName))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
            }
            .padding(14)
            .glassCard(cornerRadius: 14)

            manualFallbackButtons
        }
    }

    private var manualFallbackButtons: some View {
        VStack(spacing: 10) {
            Button {
                // Add to shopping list manually
                NotificationCenter.default.post(
                    name: .addToShoppingListManual,
                    object: nil,
                    userInfo: ["name": productName]
                )
                dismiss()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "cart.fill")
                        .font(.caption)
                    Text(String(format: l10n.t("inventory.addToShoppingManual"), productName))
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(.orange)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.orange.opacity(0.3), lineWidth: 1))
            }
            .buttonStyle(PressButtonStyle())

            Button {
                // Open full catalog search
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    stockVM.catalogSearch = productName
                    stockVM.showAddSheet = true
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.caption)
                    Text(l10n.t("inventory.browseCatalog"))
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.white.opacity(0.1), lineWidth: 1))
            }
            .buttonStyle(PressButtonStyle())
        }
    }

    // MARK: - Inventory Form (quantity, price, expiry)

    private var inventoryForm: some View {
        VStack(spacing: 14) {
            Text(l10n.t("inventory.details"))
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .frame(maxWidth: .infinity, alignment: .leading)

            formField(title: l10n.t("recipes.quantity"), text: $quantity, icon: "number", keyboard: .decimalPad, suffix: unitLabel)
            formField(title: l10n.t("recipes.price"), text: $price, icon: "banknote", keyboard: .decimalPad, suffix: currencySymbol)
            formField(title: l10n.t("recipes.expiryDays"), text: $expiryDays, icon: "calendar", keyboard: .numberPad, suffix: l10n.t("recipes.days"))
        }
        .padding(16)
        .glassCard(cornerRadius: 16)
    }

    // MARK: - Save Button

    private var saveButton: some View {
        Button {
            Task { await save() }
        } label: {
            HStack(spacing: 8) {
                if isSaving {
                    ProgressView().tint(.white)
                } else if showSuccess {
                    Image(systemName: "checkmark.circle.fill")
                } else {
                    Image(systemName: mode.isEdit ? "square.and.pencil" : "plus.circle.fill")
                }
                Text(isSaving ? l10n.t("recipes.adding") : showSuccess ? "✓" : mode.isEdit ? l10n.t("inventory.save") : l10n.t("recipes.addToStock"))
                    .fontWeight(.semibold)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                (showSuccess ? Color.green : Color.green).gradient,
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
        }
        .disabled(isSaving || quantity.isEmpty)
        .opacity((isSaving || quantity.isEmpty) ? 0.5 : 1)
    }

    // MARK: - Form Field

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

    // MARK: - Prefill

    private func prefill() {
        switch mode {
        case .addNew:
            quantity = "1"
            price = ""
            expiryDays = "7"
        case .addBatch:
            quantity = "1"
            price = ""
            expiryDays = "7"
        case .editExisting(let item):
            quantity = item.quantity.truncatingRemainder(dividingBy: 1) == 0
                ? String(format: "%.0f", item.quantity)
                : String(format: "%.1f", item.quantity)
            price = String(format: "%.2f", item.pricePerUnit)
            if let days = item.expiresIn {
                expiryDays = "\(max(days, 0))"
            } else {
                expiryDays = "30"
            }
        }
    }

    // MARK: - Catalog Search

    private func searchCatalog() async {
        guard !searchText.isEmpty else { return }
        isSearching = true
        do {
            catalogResults = try await APIClient.shared.searchCatalogIngredients(query: searchText, limit: 10)
            if catalogResults.isEmpty {
                showManualFallback = true
            }
        } catch {
            catalogResults = []
            showManualFallback = true
        }
        isSearching = false
    }

    // MARK: - Save

    private func save() async {
        guard let qty = Double(quantity.replacingOccurrences(of: ",", with: ".")), qty > 0 else {
            errorMessage = l10n.t("inventory.invalidQuantity")
            return
        }
        let priceVal = Double(price.replacingOccurrences(of: ",", with: ".")) ?? 0
        let priceCents = Int(priceVal * 100)
        let days = Int(expiryDays) ?? 7

        isSaving = true
        errorMessage = nil

        switch mode {
        case .addNew:
            guard let ingredient = selectedIngredient else { return }
            await saveNewItem(ingredientId: ingredient.id, qty: qty, priceCents: priceCents, days: days)

        case .addBatch(let productId, _, _):
            // Find catalog ingredient by product id
            // The productId here is the catalog ingredient id
            await saveNewItem(ingredientId: productId, qty: qty, priceCents: priceCents, days: days)

        case .editExisting(let item):
            await updateExistingItem(item: item, qty: qty, priceCents: priceCents)
        }

        isSaving = false
    }

    private func saveNewItem(ingredientId: String, qty: Double, priceCents: Int, days: Int) async {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let now = formatter.string(from: Date())
        let expiry = formatter.string(from: Date().addingTimeInterval(Double(days) * 86400))

        let request = APIClient.AddInventoryRequest(
            catalogIngredientId: ingredientId,
            pricePerUnitCents: priceCents,
            quantity: qty,
            receivedAt: now,
            expiresAt: expiry
        )

        do {
            let newItem = try await APIClient.shared.addInventoryProduct(request)
            stockVM.items.append(StockItem(from: newItem))
            showSuccess = true
            try? await Task.sleep(for: .milliseconds(600))
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func updateExistingItem(item: StockItem, qty: Double, priceCents: Int) async {
        do {
            try await APIClient.shared.updateInventoryProduct(id: item.backendId, quantity: qty, priceCents: priceCents)
            await stockVM.loadInventory()
            showSuccess = true
            try? await Task.sleep(for: .milliseconds(600))
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Mode Helpers

extension InventoryEditorMode {
    var isEdit: Bool {
        if case .editExisting = self { return true }
        return false
    }
}

// MARK: - Notification for manual shopping list add

extension Notification.Name {
    static let addToShoppingListManual = Notification.Name("addToShoppingListManual")
}
