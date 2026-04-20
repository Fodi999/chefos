import SwiftUI
import Combine

/// Lightweight favorite dish stored locally (UserDefaults).
struct FavoriteDish: Codable, Identifiable {
    var id: String { dishName }
    let dishName: String
    let displayName: String
    let dishType: String
    let complexity: String
    let servings: Int
    let perServingKcal: Int
    let perServingProteinG: Double
    let perServingFatG: Double
    let perServingCarbsG: Double
    let ingredientNames: [String]
    let stepsCount: Int
    let savedAt: Date

    init(from dish: APIClient.SuggestedDish) {
        self.dishName = dish.dishName
        self.displayName = dish.displayName ?? dish.dishNameLocal ?? dish.dishName
        self.dishType = dish.dishType
        self.complexity = dish.complexity
        self.servings = dish.servings
        self.perServingKcal = dish.perServingKcal
        self.perServingProteinG = dish.perServingProteinG
        self.perServingFatG = dish.perServingFatG
        self.perServingCarbsG = dish.perServingCarbsG
        self.ingredientNames = dish.ingredients.map(\.name)
        self.stepsCount = dish.steps.count
        self.savedAt = Date()
    }
}

@MainActor
final class FavoritesViewModel: ObservableObject {
    @Published var favorites: [FavoriteDish] = []

    private let key = "chef_favorites_v1"

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
