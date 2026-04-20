//
//  RecipesViewModel.swift
//  ChefOS
//

import SwiftUI
import Combine

// MARK: - ViewModels/Recipes

final class RecipesViewModel: ObservableObject {
    @Published var recipes: [Recipe] = []
    @Published var stockItems: [StockItem] = []
    @Published var isLoadingStock = false
    @Published var searchText: String = ""
    @Published var showStock: Bool = false
    @Published var stockFilter: StockFilter = .all
    @Published var cookFilter: CookFilter = .all
    @Published var showCookedBanner: Bool = false
    @Published var lastCookedTitle: String = ""
    @Published var shoppingList: [String] = []
    @Published var cookedRecipeId: UUID? = nil          // fade-out animation
    @Published var cookDeductions: [String] = []        // "-200g Pasta" lines

    // Daily budget (zł) — later connect to Profile
    var dailyBudget: Double = 60.0

    enum StockFilter: String, CaseIterable {
        case all = "All"
        case expiring = "Expiring"
        case low = "Low"
    }

    enum CookFilter: String, CaseIterable {
        case all = "All"
        case canCook = "Can cook"
        case cheapest = "Cheapest"
        case highProtein = "High protein"
    }

    struct IngredientStatus: Identifiable {
        var id: String { name }
        let name: String
        let qty: String
        let inStock: Bool
    }

    // MARK: - Stock

    var filteredStock: [StockItem] {
        var items = stockItems
        if !searchText.isEmpty {
            items = items.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        switch stockFilter {
        case .all: break
        case .expiring: items = items.filter { $0.isExpiringSoon }
        case .low: items = items.filter { $0.isLow }
        }
        return items
    }

    var groupedStock: [(category: String, items: [StockItem])] {
        let dict = Dictionary(grouping: filteredStock) { $0.category }
        return dict.keys.sorted().compactMap { cat in
            guard let items = dict[cat], !items.isEmpty else { return nil }
            return (category: cat, items: items)
        }
    }

    var totalStockValue: Double {
        stockItems.reduce(0) { $0 + $1.totalPrice }
    }

    var expiringCount: Int {
        stockItems.filter { $0.isExpiringSoon }.count
    }

    var lowCount: Int {
        stockItems.filter { $0.isLow }.count
    }

    func removeStock(at offsets: IndexSet) {
        let toRemove = offsets.map { filteredStock[$0].id }
        stockItems.removeAll { toRemove.contains($0.id) }
    }

    // MARK: - Recipes + Stock awareness

    var filteredRecipes: [Recipe] {
        var list = recipes
        if !searchText.isEmpty {
            list = list.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }
        switch cookFilter {
        case .all: break
        case .canCook: list = list.filter { canCook($0) }
        case .cheapest: list = list.sorted { $0.costPerServing < $1.costPerServing }
        case .highProtein: list = list.sorted { $0.protein > $1.protein }
        }
        return list
    }

    /// Stock item names (lowercased) for matching
    private var stockNames: Set<String> {
        Set(stockItems.map { $0.name.lowercased() })
    }

    private func matchesStock(_ ingredientName: String) -> Bool {
        stockNames.contains(where: { $0.contains(ingredientName.lowercased()) || ingredientName.lowercased().contains($0) })
    }

    func findStockItem(for ingredientName: String) -> StockItem? {
        stockItems.first { item in
            item.name.lowercased().contains(ingredientName.lowercased()) ||
            ingredientName.lowercased().contains(item.name.lowercased())
        }
    }

    func availableIngredients(for recipe: Recipe) -> [String] {
        recipe.ingredients.filter { matchesStock($0) }
    }

    func missingIngredients(for recipe: Recipe) -> [String] {
        recipe.ingredients.filter { !matchesStock($0) }
    }

    func canCook(_ recipe: Recipe) -> Bool {
        missingIngredients(for: recipe).isEmpty
    }

    var canCookRecipes: [Recipe] {
        filteredRecipes.filter { canCook($0) }
    }

    var missingRecipes: [Recipe] {
        filteredRecipes.filter { !canCook($0) }
    }

    /// Ingredient status for detail: name, quantity string, and stock availability.
    func ingredientStatus(for recipe: Recipe) -> [IngredientStatus] {
        recipe.recipeIngredients.map { ri in
            let inStock = matchesStock(ri.name)
            let qtyStr = ri.quantity.truncatingRemainder(dividingBy: 1) == 0
                ? "\(Int(ri.quantity))\(ri.unit)"
                : String(format: "%.1f%@", ri.quantity, ri.unit)
            return IngredientStatus(name: ri.name, qty: qtyStr, inStock: inStock)
        }
    }

    /// Budget percentage
    func budgetPercent(for recipe: Recipe) -> Int {
        guard dailyBudget > 0 else { return 0 }
        return Int((recipe.estimatedCost / dailyBudget) * 100)
    }

    func priceTag(for recipe: Recipe) -> (label: String, color: Color) {
        let pct = budgetPercent(for: recipe)
        if pct <= 15 { return ("Budget", .green) }
        if pct <= 30 { return ("Average", .orange) }
        return ("Premium", .red)
    }

    // MARK: - Actions

    func cookRecipe(_ recipe: Recipe) {
        var deductions: [String] = []

        // Deduct ingredients from stock
        for ri in recipe.recipeIngredients {
            guard let idx = stockItems.firstIndex(where: {
                $0.name.lowercased().contains(ri.name.lowercased()) ||
                ri.name.lowercased().contains($0.name.lowercased())
            }) else { continue }

            // Simplified deduction — convert to same scale
            let deduction = deductionAmount(needed: ri.quantity, neededUnit: ri.unit, stockUnit: stockItems[idx].unit)
            let displayUnit = ri.unit
            let displayQty = ri.quantity.truncatingRemainder(dividingBy: 1) == 0
                ? "\(Int(ri.quantity))" : String(format: "%.1f", ri.quantity)
            deductions.append("-\(displayQty)\(displayUnit) \(ri.name)")

            stockItems[idx].quantity = max(0, stockItems[idx].quantity - deduction)
            stockItems[idx].totalPrice = stockItems[idx].quantity * stockItems[idx].pricePerUnit

            // Remove if depleted
            if stockItems[idx].quantity <= 0 {
                stockItems.remove(at: idx)
            }
        }

        cookDeductions = deductions
        lastCookedTitle = recipe.title

        // Fade out card
        withAnimation(.easeOut(duration: 0.4)) {
            cookedRecipeId = recipe.id
        }

        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            showCookedBanner = true
        }

        // Reset fade after banner shown
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeIn(duration: 0.3)) {
                self.cookedRecipeId = nil
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            withAnimation(.easeOut(duration: 0.3)) {
                self.showCookedBanner = false
            }
        }
    }

    private func deductionAmount(needed: Double, neededUnit: String, stockUnit: StockItem.StockUnit) -> Double {
        // Convert grams → kg for stock items stored in kg
        if neededUnit == "g" && stockUnit == .kg { return needed / 1000.0 }
        if neededUnit == "ml" && stockUnit == .l { return needed / 1000.0 }
        return needed
    }

    func addToShoppingList(recipe: Recipe) {
        let missing = missingIngredients(for: recipe)
        for item in missing where !shoppingList.contains(item) {
            shoppingList.append(item)
        }
    }

    func deleteRecipe(at offsets: IndexSet) {
        for index in offsets.sorted(by: >) {
            recipes.remove(at: index)
        }
    }

    func addRecipe(_ recipe: Recipe) {
        recipes.append(recipe)
    }

    // MARK: - Strategy Engine

    struct StrategyTip: Identifiable {
        var id: String { icon + text }
        let icon: String
        let text: String
        let color: Color
    }

    func strategyTips(plan: PlanViewModel) -> [StrategyTip] {
        var tips: [StrategyTip] = []

        // Budget awareness
        if plan.totalCost > plan.budgetTarget {
            tips.append(.init(icon: "banknote.fill", text: "Over budget — try cheaper meals", color: .red))
        } else if plan.totalCost > plan.budgetTarget * 0.8 && plan.filledCount < 3 {
            tips.append(.init(icon: "exclamationmark.triangle.fill", text: "Budget running low — pick wisely", color: .orange))
        }

        // Protein gap
        let proteinGap = plan.proteinTarget - plan.totalProtein
        if proteinGap > 30 {
            tips.append(.init(icon: "bolt.fill", text: "Need \(proteinGap)g more protein today", color: .cyan))
        }

        // Calorie gap
        let calGap = plan.calorieTarget - plan.totalCalories
        if calGap < -200 {
            tips.append(.init(icon: "flame.fill", text: "Over calorie target — lighter options below", color: .red))
        } else if calGap > 500 && plan.filledCount > 0 {
            tips.append(.init(icon: "leaf.fill", text: "\(calGap) kcal left — room for a hearty meal", color: .green))
        }

        // Expiring stock
        if expiringCount > 0 {
            let expNames = stockItems.filter { $0.isExpiringSoon }.prefix(2).map { $0.name }.joined(separator: ", ")
            tips.append(.init(icon: "clock.badge.exclamationmark.fill", text: "Use \(expNames) before they expire", color: .orange))
        }

        // Default
        if tips.isEmpty {
            tips.append(.init(icon: "sparkles", text: "You're on track — pick what you love", color: .green))
        }

        return tips
    }

    // MARK: - Backend

    private let api = APIClient.shared

    @MainActor
    func loadStock() async {
        isLoadingStock = true
        do {
            let response = try await api.listInventory()
            stockItems = response.items.map { StockItem(from: $0) }
        } catch {
            print("Failed to load stock: \(error)")
        }
        isLoadingStock = false
    }
}
