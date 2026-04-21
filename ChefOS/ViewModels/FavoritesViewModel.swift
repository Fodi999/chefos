import SwiftUI
import Combine

/// Full favorite dish stored locally (UserDefaults).
struct FavoriteDish: Codable, Identifiable {
    var id: String { dishName }
    let dishName: String
    let dishNameLocal: String?
    let displayName: String
    let dishType: String
    let complexity: String
    let servings: Int
    // Per-serving nutrition
    let perServingKcal: Int
    let perServingProteinG: Double
    let perServingFatG: Double
    let perServingCarbsG: Double
    // Total nutrition
    let totalKcal: Int
    let totalProteinG: Double
    let totalFatG: Double
    let totalCarbsG: Double
    // Ingredients (full)
    let ingredients: [SavedIngredient]
    let missingIngredients: [String]
    let missingCount: Int
    // Steps (full)
    let steps: [SavedStep]
    // Insight
    let insight: SavedInsight
    // Extra
    let tags: [String]
    let allergens: [String]
    let warnings: [String]
    let savedAt: Date

    // Computed helpers
    var ingredientNames: [String] { ingredients.map(\.name) }
    var stepsCount: Int { steps.count }

    struct SavedIngredient: Codable {
        let name: String
        let slug: String
        let grossG: Double
        let role: String
        let available: Bool
        let expiringSoon: Bool
    }

    struct SavedStep: Codable {
        let step: Int
        let text: String
        let timeMin: Int?
        let tempC: Int?
        let tip: String?
    }

    struct SavedInsight: Codable {
        let usesExpiring: Bool
        let highProtein: Bool
        let budgetFriendly: Bool
        let estimatedCostCents: Int
        let priorityScore: Int
        let reasons: [String]
    }

    init(from dish: APIClient.SuggestedDish) {
        self.dishName = dish.dishName
        self.dishNameLocal = dish.dishNameLocal
        self.displayName = dish.displayName ?? dish.dishNameLocal ?? dish.dishName
        self.dishType = dish.dishType
        self.complexity = dish.complexity
        self.servings = dish.servings
        self.perServingKcal = dish.perServingKcal
        self.perServingProteinG = dish.perServingProteinG
        self.perServingFatG = dish.perServingFatG
        self.perServingCarbsG = dish.perServingCarbsG
        self.totalKcal = dish.totalKcal
        self.totalProteinG = dish.totalProteinG
        self.totalFatG = dish.totalFatG
        self.totalCarbsG = dish.totalCarbsG
        self.ingredients = dish.ingredients.map {
            SavedIngredient(name: $0.name, slug: $0.slug, grossG: $0.grossG,
                            role: $0.role, available: $0.available, expiringSoon: $0.expiringSoon)
        }
        self.missingIngredients = dish.missingIngredients
        self.missingCount = dish.missingCount
        self.steps = dish.steps.map {
            SavedStep(step: $0.step, text: $0.text, timeMin: $0.timeMin,
                      tempC: $0.tempC, tip: $0.tip)
        }
        self.insight = SavedInsight(
            usesExpiring: dish.insight.usesExpiring,
            highProtein: dish.insight.highProtein,
            budgetFriendly: dish.insight.budgetFriendly,
            estimatedCostCents: dish.insight.estimatedCostCents,
            priorityScore: dish.insight.priorityScore,
            reasons: dish.insight.reasons
        )
        self.tags = dish.tags
        self.allergens = dish.allergens
        self.warnings = dish.warnings
        self.savedAt = Date()
    }
}

@MainActor
final class FavoritesViewModel: ObservableObject {
    @Published var favorites: [FavoriteDish] = []

    private let key = "chef_favorites_v2"

    init() { load() }

    var isEmpty: Bool { favorites.isEmpty }

    func isFavorite(_ dishName: String) -> Bool {
        favorites.contains { $0.dishName == dishName }
    }

    func toggle(_ dish: APIClient.SuggestedDish) {
        if let idx = favorites.firstIndex(where: { $0.dishName == dish.dishName }) {
            favorites.remove(at: idx)
        } else {
            favorites.insert(FavoriteDish(from: dish), at: 0)
        }
        save()
    }

    func toggle(_ fav: FavoriteDish) {
        if let idx = favorites.firstIndex(where: { $0.dishName == fav.dishName }) {
            favorites.remove(at: idx)
            save()
        }
    }

    func isFavorite(_ dish: FavoriteDish) -> Bool {
        favorites.contains { $0.dishName == dish.dishName }
    }

    func remove(at offsets: IndexSet) {
        favorites.remove(atOffsets: offsets)
        save()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([FavoriteDish].self, from: data) else { return }
        favorites = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(favorites) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
