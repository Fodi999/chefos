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
    /// Purchase date (when the item was bought / received). Defaults to now.
    @Published var addPurchaseDate: Date = Date()
    /// Expiry date — recomputed from `addPurchaseDate + addExpiryDays` when the
    /// user taps a preset chip or changes the day field; can also be picked
    /// directly via a `DatePicker`.
    @Published var addExpiryDate: Date = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
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

    // MARK: - Inventory Analysis (what's missing)

    private static let proteinKeywords = ["chicken", "egg", "fish", "meat", "beef", "pork", "turkey", "salmon", "tuna", "shrimp",
                                           "курица", "яйц", "рыба", "мясо", "говядина", "свинина", "индейка", "лосось", "тунец", "креветк",
                                           "kurczak", "jajk", "ryba", "mięso", "wołowin", "wieprzow", "indyk", "łosoś",
                                           "курка", "яйця", "риба", "м'ясо"]

    private static let baseKeywords = ["rice", "pasta", "potato", "bread", "noodle", "flour", "oat", "buckwheat",
                                        "рис", "паста", "картоф", "хлеб", "лапша", "мука", "овсян", "гречк",
                                        "ryż", "makaron", "ziemniak", "chleb", "mąka", "owsian", "gryczana",
                                        "рис", "паста", "картопл", "хліб", "борошно", "вівсян", "гречка"]

    private static let vegetableKeywords = ["tomato", "onion", "carrot", "pepper", "cabbage", "cucumber", "garlic", "broccoli",
                                             "помидор", "лук", "морков", "перец", "капуст", "огурец", "чеснок", "брокколи",
                                             "pomidor", "cebul", "marchew", "papryk", "kapust", "ogórek", "czosnek",
                                             "помідор", "цибул", "морков", "перець", "капуст", "огірок", "часник"]

    var hasProtein: Bool {
        items.contains { item in Self.proteinKeywords.contains { item.name.lowercased().contains($0) } }
    }

    var hasBase: Bool {
        items.contains { item in Self.baseKeywords.contains { item.name.lowercased().contains($0) } }
    }

    var hasVegetables: Bool {
        items.contains { item in Self.vegetableKeywords.contains { item.name.lowercased().contains($0) } }
    }

    /// Category analysis: what types of ingredients the user is missing
    var missingCategories: [String] {
        var missing: [String] = []
        if !hasProtein { missing.append("protein") }
        if !hasBase { missing.append("base") }
        if !hasVegetables { missing.append("vegetable") }
        return missing
    }

    /// Dominant category of current inventory
    var inventoryProfile: String {
        let categories = items.map { $0.category.lowercased() }
        let counts = Dictionary(grouping: categories) { $0 }.mapValues(\.count)
        return counts.max(by: { $0.value < $1.value })?.key ?? "mixed"
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

    /// Quick-add a product by searching catalog by name, then adding with defaults
    func quickAddProduct(name: String, quantity: Double = 1.0, priceCents: Int = 500, expiryDays: Int = 7) async -> Bool {
        do {
            let results = try await api.searchCatalogIngredients(query: name, limit: 5)
            guard let ingredient = results.first else { return false }

            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let now = formatter.string(from: Date())
            let expiry = formatter.string(from: Date().addingTimeInterval(Double(expiryDays) * 86400))

            let request = APIClient.AddInventoryRequest(
                catalogIngredientId: ingredient.id,
                pricePerUnitCents: priceCents,
                quantity: quantity,
                receivedAt: now,
                expiresAt: expiry
            )

            let newItem = try await api.addInventoryProduct(request)
            items.append(StockItem(from: newItem))
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func addProduct() async {
        guard let ingredient = selectedIngredient else { return }
        guard let qty = Double(addQuantity), qty > 0 else { return }
        let price = Double(addPrice.replacingOccurrences(of: ",", with: ".")) ?? 0
        let priceCents = Int(price * 100)

        // Guard against inverted dates: if the user picked an expiry that is
        // earlier than the purchase date, clamp it to purchase + 1 day so the
        // backend receives a valid interval.
        let purchase = addPurchaseDate
        let expiry: Date = {
            if addExpiryDate > purchase { return addExpiryDate }
            return Calendar.current.date(byAdding: .day, value: 1, to: purchase) ?? purchase
        }()

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let receivedAt = formatter.string(from: purchase)
        let expiresAt  = formatter.string(from: expiry)

        let request = APIClient.AddInventoryRequest(
            catalogIngredientId: ingredient.id,
            pricePerUnitCents: priceCents,
            quantity: qty,
            receivedAt: receivedAt,
            expiresAt: expiresAt
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

    // MARK: - Add-form helpers

    /// Called by the view right after the user picks an ingredient from the
    /// catalog list. Sets sane defaults for quantity, purchase/expiry dates
    /// from `defaultShelfLifeDays`, and pre-fills the shelf-life text field.
    func primeAddForm(for ingredient: APIClient.CatalogIngredientDTO) {
        let days = ingredient.defaultShelfLifeDays ?? 7
        selectedIngredient = ingredient
        addQuantity = "1"
        addPrice = ""
        addExpiryDays = "\(days)"
        addPurchaseDate = Date()
        addExpiryDate = Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? Date()
    }

    /// Keep `addExpiryDate` in sync when the user types a number into the
    /// shelf-life field.
    func syncExpiryFromDays() {
        guard let d = Int(addExpiryDays), d >= 0 else { return }
        addExpiryDate = Calendar.current.date(byAdding: .day, value: d, to: addPurchaseDate) ?? addPurchaseDate
    }

    /// Keep `addExpiryDays` text in sync when the user picks a date directly.
    func syncDaysFromExpiry() {
        let d = Calendar.current.dateComponents([.day], from: addPurchaseDate, to: addExpiryDate).day ?? 0
        addExpiryDays = "\(max(d, 0))"
    }

    /// Quick chips (+3 / +7 / +14 / +30) — bump the expiry date relative to the
    /// purchase date, and mirror the day count in the text field.
    func setShelfLifeDays(_ days: Int) {
        addExpiryDays = "\(days)"
        addExpiryDate = Calendar.current.date(byAdding: .day, value: days, to: addPurchaseDate) ?? addPurchaseDate
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
        addPurchaseDate = Date()
        addExpiryDate = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        catalogSearch = ""
        catalogIngredients = []
        selectedCategoryId = nil
    }
}
