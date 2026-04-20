//
//  StockViewModel.swift
//  ChefOS
//

import SwiftUI
import Combine

// MARK: - ViewModels/Stock

@MainActor
final class StockViewModel: ObservableObject {
    private let api = APIClient.shared

    // MARK: - Inventory (from backend)
    @Published var items: [StockItem] = []
    @Published var isLoading = false
    @Published var error: String?

    // MARK: - Catalog (for adding new items)
    @Published var categories: [APIClient.CatalogCategoryDTO] = []
    @Published var catalogIngredients: [APIClient.CatalogIngredientDTO] = []
    @Published var selectedCategoryId: String?
    @Published var catalogSearch = ""
    @Published var isSearching = false

    // MARK: - Add form
    @Published var showAddSheet = false
    @Published var showSuccessBanner = false
    @Published var selectedIngredient: APIClient.CatalogIngredientDTO?
    @Published var addQuantity = ""
    @Published var addPrice = ""
    @Published var addExpiryDays = "7"
    @Published var isSaving = false

    // MARK: - Filters
    @Published var searchText = ""
    @Published var stockFilter: StockFilter = .all

    enum StockFilter: Hashable {
        case all
        case expiring
        case low
        case category(String)   // category name from backend (already localized)
    }

    /// Dynamic filters: all + expiring + low + real categories from inventory
    var availableFilters: [StockFilter] {
        var filters: [StockFilter] = [.all]
        if expiringCount > 0 { filters.append(.expiring) }
        if lowCount > 0 { filters.append(.low) }
        let cats = Set(items.map(\.category)).sorted()
        for cat in cats {
            filters.append(.category(cat))
        }
        return filters
    }

    // MARK: - Product Group (same product, multiple inventory entries)

    struct ProductGroup: Identifiable {
        let id: String           // productId
        let name: String
        let category: String
        let unit: StockItem.StockUnit
        let imageUrl: String?
        var entries: [StockItem]  // individual inventory records (different purchase dates/prices/expiry)

        var totalQuantity: Double { entries.reduce(0) { $0 + $1.quantity } }
        var totalValue: Double { entries.reduce(0) { $0 + $1.totalPrice } }
        var avgPricePerUnit: Double { totalQuantity > 0 ? totalValue / totalQuantity : 0 }
        var soonestExpiry: Int? { entries.compactMap(\.expiresIn).min() }
        var isExpiringSoon: Bool { (soonestExpiry ?? 999) <= 3 }
        var isLow: Bool { totalQuantity <= 0.2 }
        var entryCount: Int { entries.count }
        /// Longest shelf life in group (for progress bar scale)
        var longestShelfLife: Int {
            entries.compactMap { item -> Int? in
                guard let expiresAt = item.expiresAt else { return nil }
                let total = Calendar.current.dateComponents([.day], from: item.purchaseDate, to: expiresAt).day ?? 7
                return max(total, 1)
            }.max() ?? 7
        }
    }

    // MARK: - Computed

    var filteredItems: [StockItem] {
        var result = items
        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        switch stockFilter {
        case .all: break
        case .expiring: result = result.filter { $0.isExpiringSoon }
        case .low: result = result.filter { $0.isLow }
        case .category(let cat): result = result.filter { $0.category == cat }
        }
        return result
    }

    /// Group by productId — same product, multiple inventory entries
    var productGroups: [ProductGroup] {
        let dict = Dictionary(grouping: filteredItems) { $0.productId.isEmpty ? $0.name : $0.productId }
        return dict.values.compactMap { entries -> ProductGroup? in
            guard let first = entries.first else { return nil }
            return ProductGroup(
                id: first.productId.isEmpty ? first.name : first.productId,
                name: first.name,
                category: first.category,
                unit: first.unit,
                imageUrl: first.imageUrl,
                entries: entries.sorted { ($0.expiresIn ?? 999) < ($1.expiresIn ?? 999) } // FIFO: soonest expiry first
            )
        }.sorted { $0.name < $1.name }
    }

    /// Group product groups by category (from backend)
    var groupedByCategory: [(category: String, groups: [ProductGroup])] {
        let dict = Dictionary(grouping: productGroups) { $0.category }
        return dict.keys.sorted().compactMap { cat in
            guard let groups = dict[cat], !groups.isEmpty else { return nil }
            return (category: cat, groups: groups)
        }
    }

    var groupedItems: [(category: String, items: [StockItem])] {
        let dict = Dictionary(grouping: filteredItems) { $0.category }
        return dict.keys.sorted().compactMap { cat in
            guard let items = dict[cat], !items.isEmpty else { return nil }
            return (category: cat, items: items)
        }
    }

    var totalValue: Double {
        items.reduce(0) { $0 + $1.totalPrice }
    }

    var expiringCount: Int {
        items.filter { $0.isExpiringSoon }.count
    }

    var lowCount: Int {
        items.filter { $0.isLow }.count
    }

    // MARK: - Smart Insights

    /// Items expiring within 3 days, sorted soonest first
    var urgentItems: [StockItem] {
        items.filter { $0.isExpiringSoon }
            .sorted { ($0.expiresIn ?? 999) < ($1.expiresIn ?? 999) }
    }

    /// Total value at risk (items expiring ≤ 3 days)
    var wasteRiskValue: Double {
        urgentItems.reduce(0) { $0 + $1.totalPrice }
    }

    /// Estimated days of food based on soonest median expiry
    var estimatedDaysOfFood: Int {
        let expiries = items.compactMap(\.expiresIn).sorted()
        guard !expiries.isEmpty else { return 0 }
        return expiries[expiries.count / 2]  // median
    }

    /// Unique product names (for "what to cook" context)
    var ingredientNames: [String] {
        Array(Set(items.map(\.name))).sorted()
    }

    /// Food emoji for a category
    static func categoryEmoji(_ category: String) -> String {
        let lower = category.lowercased()
        if lower.contains("fruit") || lower.contains("фрукт") || lower.contains("owoc") { return "🍎" }
        if lower.contains("vegetab") || lower.contains("овощ") || lower.contains("warzyw") { return "🥬" }
        if lower.contains("meat") || lower.contains("мясо") || lower.contains("мʼяс") || lower.contains("mięs") { return "🥩" }
        if lower.contains("fish") || lower.contains("seafood") || lower.contains("рыб") || lower.contains("риб") { return "🐟" }
        if lower.contains("dairy") || lower.contains("egg") || lower.contains("молоч") || lower.contains("яйц") || lower.contains("nabiał") { return "🥛" }
        if lower.contains("grain") || lower.contains("pasta") || lower.contains("крупы") || lower.contains("макарон") || lower.contains("zboż") { return "🌾" }
        if lower.contains("oil") || lower.contains("fat") || lower.contains("масл") || lower.contains("olej") { return "🫒" }
        if lower.contains("spice") || lower.contains("herb") || lower.contains("спец") || lower.contains("прян") || lower.contains("przypr") { return "🌿" }
        if lower.contains("condiment") || lower.contains("sauce") || lower.contains("соус") { return "🧂" }
        if lower.contains("beverage") || lower.contains("напит") || lower.contains("napoj") { return "🥤" }
        if lower.contains("nut") || lower.contains("seed") || lower.contains("орех") || lower.contains("горіх") { return "🥜" }
        if lower.contains("legume") || lower.contains("бобов") || lower.contains("strączk") { return "🫘" }
        if lower.contains("sweet") || lower.contains("baking") || lower.contains("выпечк") || lower.contains("сладк") { return "🍰" }
        if lower.contains("canned") || lower.contains("preserved") || lower.contains("консерв") { return "🥫" }
        if lower.contains("frozen") || lower.contains("заморож") || lower.contains("mrożon") { return "🧊" }
        return "📦"
    }

    /// Category value totals (for header display)
    func categoryValue(_ category: String) -> Double {
        items.filter { $0.category == category }.reduce(0) { $0 + $1.totalPrice }
    }

    // MARK: - Load Inventory

    func loadInventory() async {
        isLoading = true
        error = nil
        do {
            let response = try await api.listInventory()
            items = response.items.map { StockItem(from: $0) }
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Load Catalog Categories

    func loadCategories() async {
        do {
            categories = try await api.getCatalogCategories()
        } catch {
            print("Failed to load categories: \(error)")
        }
    }

    // MARK: - Search Catalog Ingredients

    func searchIngredients() async {
        isSearching = true
        do {
            let query = catalogSearch.isEmpty ? nil : catalogSearch
            catalogIngredients = try await api.searchCatalogIngredients(
                query: query,
                categoryId: selectedCategoryId,
                limit: 50
            )
        } catch {
            print("Failed to search ingredients: \(error)")
        }
        isSearching = false
    }

    // MARK: - Add Product to Inventory

    func addProduct() async {
        guard let ingredient = selectedIngredient else { return }
        guard let qty = Double(addQuantity), qty > 0 else { return }
        let price = Double(addPrice.replacingOccurrences(of: ",", with: ".")) ?? 0
        let priceCents = Int(price * 100)
        let days = Int(addExpiryDays) ?? 7

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let now = formatter.string(from: Date())
        let expiry = formatter.string(from: Date().addingTimeInterval(Double(days) * 86400))

        let request = APIClient.AddInventoryRequest(
            catalogIngredientId: ingredient.id,
            pricePerUnitCents: priceCents,
            quantity: qty,
            receivedAt: now,
            expiresAt: expiry
        )

        isSaving = true
        do {
            let newItem = try await api.addInventoryProduct(request)
            items.append(StockItem(from: newItem))
            showSuccessBanner = true
            try? await Task.sleep(for: .milliseconds(800))
            resetAddForm()
            showAddSheet = false
            showSuccessBanner = false
        } catch {
            self.error = error.localizedDescription
        }
        isSaving = false
    }

    // MARK: - Delete Product

    func deleteProduct(_ item: StockItem) async {
        do {
            try await api.deleteInventoryProduct(id: item.backendId)
            items.removeAll { $0.backendId == item.backendId }
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Update Product (quantity / price only — user's inventory)

    func updateProduct(_ item: StockItem, newQuantity: Double?, newPriceCents: Int?) async {
        do {
            try await api.updateInventoryProduct(id: item.backendId, quantity: newQuantity, priceCents: newPriceCents)
            // Reload to get fresh data
            await loadInventory()
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Helpers

    private func resetAddForm() {
        selectedIngredient = nil
        addQuantity = ""
        addPrice = ""
        addExpiryDays = "7"
        catalogSearch = ""
        catalogIngredients = []
        selectedCategoryId = nil
    }
}
