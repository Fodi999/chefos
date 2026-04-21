//
//  Models.swift
//  ChefOS
//

import Foundation
import UIKit

// MARK: - Models

// MARK: UserProfile

struct UserProfile {
    var name: String = "User"
    var age: Int = 25
    var weight: Double = 70.0

    // Region
    var countryCode: String = Locale.current.region?.identifier ?? "US"

    // Goals
    var goal: FitnessGoal = .loseFat
    var targetWeight: Double = 65.0
    var calorieTarget: Int = 2200
    var proteinTarget: Int = 120

    // Diet & Preferences
    var diet: DietType = .noRestrictions
    var likes: [String] = []
    var dislikes: [String] = []
    var preferredCuisine: CuisineType = .any

    // Restrictions
    var allergies: [String] = []
    var intolerances: [String] = []
    var medicalConditions: [String] = []

    // Lifestyle
    var cookingLevel: CookingLevel = .homeCook
    var cookingTime: CookingTime = .medium
    var mealsPerDay: Int = 3

    // MARK: Enums

    enum FitnessGoal: String, CaseIterable, Identifiable {
        case loseFat = "Lose fat"
        case gainMuscle = "Gain muscle"
        case maintainWeight = "Maintain weight"
        case eatHealthier = "Eat healthier"
        case medicalDiet = "Medical diet"
        var id: String { rawValue }
        var l10nKey: String {
            switch self {
            case .loseFat: "goal.loseFat"
            case .gainMuscle: "goal.gainMuscle"
            case .maintainWeight: "goal.maintainWeight"
            case .eatHealthier: "goal.eatHealthier"
            case .medicalDiet: "goal.medicalDiet"
            }
        }
        var emoji: String {
            switch self {
            case .loseFat: "🔥"
            case .gainMuscle: "💪"
            case .maintainWeight: "⚖️"
            case .eatHealthier: "🥗"
            case .medicalDiet: "🏥"
            }
        }
    }

    enum DietType: String, CaseIterable, Identifiable {
        case noRestrictions = "No restrictions"
        case vegetarian = "Vegetarian"
        case vegan = "Vegan"
        case keto = "Keto"
        case paleo = "Paleo"
        case glutenFree = "Gluten-free"
        case dairyFree = "Dairy-free"
        var id: String { rawValue }
        var l10nKey: String {
            switch self {
            case .noRestrictions: "diet.noRestrictions"
            case .vegetarian: "diet.vegetarian"
            case .vegan: "diet.vegan"
            case .keto: "diet.keto"
            case .paleo: "diet.paleo"
            case .glutenFree: "diet.glutenFree"
            case .dairyFree: "diet.dairyFree"
            }
        }
        var emoji: String {
            switch self {
            case .noRestrictions: "🍽"
            case .vegetarian: "🥬"
            case .vegan: "🌱"
            case .keto: "🥑"
            case .paleo: "🦴"
            case .glutenFree: "🚫"
            case .dairyFree: "🥛"
            }
        }
    }

    enum CookingLevel: String, CaseIterable, Identifiable {
        case beginner = "Beginner"
        case homeCook = "Home cook"
        case advanced = "Advanced"
        case chef = "Chef"
        var id: String { rawValue }
        var l10nKey: String {
            switch self {
            case .beginner: "cooking.beginner"
            case .homeCook: "cooking.homeCook"
            case .advanced: "cooking.advanced"
            case .chef: "cooking.chef"
            }
        }
        var emoji: String {
            switch self {
            case .beginner: "🌱"
            case .homeCook: "🏠"
            case .advanced: "⭐"
            case .chef: "👨‍🍳"
            }
        }
    }

    enum CookingTime: String, CaseIterable, Identifiable {
        case quick = "≤ 15 min"
        case medium = "≤ 30 min"
        case long = "≤ 60 min"
        case any = "Any"
        var id: String { rawValue }
        var l10nKey: String {
            switch self {
            case .quick: "time.quick"
            case .medium: "time.medium"
            case .long: "time.long"
            case .any: "time.any"
            }
        }
        var emoji: String {
            switch self {
            case .quick: "⚡"
            case .medium: "⏱"
            case .long: "🕐"
            case .any: "♾️"
            }
        }
    }

    enum CuisineType: String, CaseIterable, Identifiable {
        case any = "Any"
        case asian = "Asian"
        case mediterranean = "Mediterranean"
        case american = "American"
        case mexican = "Mexican"
        case italian = "Italian"
        case middleEastern = "Middle Eastern"
        var id: String { rawValue }
        var l10nKey: String {
            switch self {
            case .any: "cuisine.any"
            case .asian: "cuisine.asian"
            case .mediterranean: "cuisine.mediterranean"
            case .american: "cuisine.american"
            case .mexican: "cuisine.mexican"
            case .italian: "cuisine.italian"
            case .middleEastern: "cuisine.middleEastern"
            }
        }
        var emoji: String {
            switch self {
            case .any: "🌍"
            case .asian: "🍜"
            case .mediterranean: "🫒"
            case .american: "🍔"
            case .mexican: "🌮"
            case .italian: "🍝"
            case .middleEastern: "🧆"
            }
        }
    }

    // MARK: AI Summary

    var aiSummary: String {
        localizedAiSummary(LocalizationService.shared)
    }

    func localizedAiSummary(_ l10n: LocalizationService) -> String {
        var lines: [String] = []
        lines.append("\(l10n.t("ai.goal")): \(l10n.t(goal.l10nKey))")
        lines.append("\(l10n.t("ai.calories")): \(calorieTarget) \(l10n.t("ai.kcal")) · \(l10n.t("ai.protein")): \(proteinTarget)\(l10n.t("ai.g"))")
        if diet != .noRestrictions { lines.append("\(l10n.t("ai.diet")): \(l10n.t(diet.l10nKey))") }
        if !allergies.isEmpty { lines.append("\(l10n.t("ai.avoid")): \(allergies.joined(separator: ", "))") }
        if cookingTime != .any { lines.append("\(l10n.t("ai.time")): \(l10n.t(cookingTime.l10nKey))") }
        lines.append("\(l10n.t("ai.level")): \(l10n.t(cookingLevel.l10nKey))")
        return lines.joined(separator: "\n")
    }
}

// MARK: RecipeStep (rich)

struct RecipeStepDetail: Identifiable {
    let id: Int
    let text: String
    let timeMin: Int?
    let tempC: Int?
    let tip: String?
}

// MARK: RecipeIngredient

struct RecipeIngredient: Identifiable {
    let id = UUID()
    var name: String
    var quantity: Double
    var unit: String
    var role: String = ""
    var available: Bool = true
}

// MARK: Recipe

struct Recipe: Identifiable {
    let id = UUID()
    var title: String
    var calories: Int
    var protein: Int = 0
    var fat: Int = 0
    var carbs: Int = 0
    var servings: Int = 2
    var dishType: String = ""
    var complexity: String = ""
    var ingredients: [String]
    var recipeIngredients: [RecipeIngredient] = []
    var richSteps: [RecipeStepDetail] = []
    var steps: [String]
    var imageName: String? = nil
    var estimatedCost: Double = 0
    var tags: [String] = []
    var warnings: [String] = []
    var missingIngredients: [String] = []
    /// Reference to source dish for favorites
    var sourceDish: APIClient.SuggestedDish? = nil
    var costPerServing: Double { servings > 0 ? estimatedCost / Double(servings) : estimatedCost }
}

extension Recipe {
    /// Bridge: create a Recipe from a backend SuggestedDish
    init(from dish: APIClient.SuggestedDish) {
        self.init(
            title: dish.displayName ?? dish.dishNameLocal ?? dish.dishName,
            calories: dish.perServingKcal,
            protein: Int(dish.perServingProteinG),
            fat: Int(dish.perServingFatG),
            carbs: Int(dish.perServingCarbsG),
            servings: max(dish.servings, 1),
            dishType: dish.dishType,
            complexity: dish.complexity,
            ingredients: dish.ingredients.map { $0.name },
            recipeIngredients: dish.ingredients.map { ing in
                RecipeIngredient(
                    name: ing.name,
                    quantity: Double(ing.grossG),
                    unit: "g",
                    role: ing.role,
                    available: ing.available
                )
            },
            richSteps: dish.steps.enumerated().map { i, s in
                RecipeStepDetail(
                    id: i + 1,
                    text: s.text,
                    timeMin: s.timeMin,
                    tempC: s.tempC,
                    tip: s.tip
                )
            },
            steps: dish.steps.map { s in
                var line = s.text
                if let t = s.timeMin { line += " (\(t) min)" }
                if let temp = s.tempC { line += " \(temp)°C" }
                return line
            },
            estimatedCost: Double(dish.insight.estimatedCostCents) / 100.0,
            tags: dish.tags,
            warnings: dish.warnings,
            missingIngredients: dish.missingIngredients,
            sourceDish: dish
        )
    }

    /// Bridge: create a Recipe from a backend chat RecipeCard (from `/public/chat`).
    /// Used when the chat bot wants to add a recipe to the plan / start cooking flow.
    init(from card: APIClient.BackendRecipeCard) {
        self.init(
            title: card.displayName ?? card.dishNameLocal ?? card.dishName,
            calories: card.perServingKcal,
            protein: Int(card.perServingProtein),
            fat: Int(card.perServingFat),
            carbs: Int(card.perServingCarbs),
            servings: max(card.servings, 1),
            dishType: card.dishType ?? "",
            complexity: card.complexity,
            ingredients: card.ingredients.map { $0.name },
            recipeIngredients: card.ingredients.map { ing in
                RecipeIngredient(
                    name: ing.name,
                    quantity: ing.grossG,
                    unit: "g",
                    role: ing.role,
                    available: true
                )
            },
            richSteps: card.steps.enumerated().map { i, s in
                RecipeStepDetail(
                    id: i + 1,
                    text: s.text,
                    timeMin: s.timeMin,
                    tempC: s.tempC,
                    tip: s.tip
                )
            },
            steps: card.steps.map { s in
                var line = s.text
                if let t = s.timeMin { line += " (\(t) min)" }
                if let temp = s.tempC { line += " \(temp)°C" }
                return line
            },
            estimatedCost: 0,
            tags: card.tags,
            warnings: [],
            missingIngredients: [],
            sourceDish: nil
        )
    }

    /// Empty fallback — no hardcoded demos
    static let samples: [Recipe] = []
}

// MARK: Message

/// Structured card types emitted by the AI greeting flow.
/// Plain AI/user replies use `.none`.
enum ChatCardType {
    case none
    case greeting(name: String)
    case goal(goal: String, focus: String)
    case dailyTargets(kcal: Int, protein: Int)
    case restrictions(items: [String])
    // Backend response cards
    case product(APIClient.BackendProductCard)
    case nutrition(APIClient.BackendNutritionCard)
    case conversion(APIClient.BackendConversionCard)
    case recipe(APIClient.BackendRecipeCard)
    case cookingLoss(APIClient.BackendCookingLossCard)
    // Feedback card — shown after an action is performed
    case confirmation(icon: String, title: String, subtitle: String, tint: ConfirmationTint)
}

enum ConfirmationTint {
    case success
    case info
    case warning
}

/// User-invokable action emitted by a chat card.
/// Dispatched through `ChatViewModel.handleAction(_:)`.
enum ChatAction {
    case addRecipeToPlan(APIClient.BackendRecipeCard)
    case startCooking(APIClient.BackendRecipeCard)
    case swapIngredient(recipe: APIClient.BackendRecipeCard, ingredient: String)
    case addProductToShopping(APIClient.BackendProductCard)
    case addProductToInventory(APIClient.BackendProductCard)
    case showRecipesFor(product: APIClient.BackendProductCard)
}

extension ChatAction {
    /// Map a typed backend action onto the local `ChatAction`, carrying the
    /// full card payload so the handler has all needed context.
    /// Returns nil for `.unknown` — forward-compat with new server-side actions.
    static func from(backend: APIClient.BackendAction,
                     recipe: APIClient.BackendRecipeCard? = nil,
                     product: APIClient.BackendProductCard? = nil) -> ChatAction? {
        switch backend {
        case .addToPlan:
            return recipe.map { .addRecipeToPlan($0) }
        case .startCooking:
            return recipe.map { .startCooking($0) }
        case .swapIngredient(_, let slug):
            guard let r = recipe else { return nil }
            return .swapIngredient(recipe: r, ingredient: slug)
        case .addToShopping:
            return product.map { .addProductToShopping($0) }
        case .showRecipesFor:
            return product.map { .showRecipesFor(product: $0) }
        case .unknown:
            return nil
        }
    }
}

// Cross-ViewModel notifications (chat → plan / shopping)
extension Notification.Name {
    static let chatDidAddRecipeToPlan   = Notification.Name("chat.addRecipeToPlan")
    static let chatDidAddToShoppingList = Notification.Name("chat.addToShoppingList")
    static let chatDidAddToInventory    = Notification.Name("chat.addToInventory")
    static let chatDidRequestCooking    = Notification.Name("chat.requestCooking")
}

enum MessageContent {
    case text(String)
    case recipeCard(Recipe)
    case image(UIImage)
}

struct Message: Identifiable {
    let id = UUID()
    let content: MessageContent
    let isFromUser: Bool
    var cardType: ChatCardType = .none
    let timestamp: Date = .now
}

// MARK: Stock / Pantry

struct StockItem: Identifiable {
    let id = UUID()
    var backendId: String = ""
    var productId: String = ""          // catalog product id — for grouping same products
    var name: String
    var quantity: Double
    var unit: StockUnit
    var pricePerUnit: Double
    var totalPrice: Double
    var purchaseDate: Date
    var expiresIn: Int?
    var expiresAt: Date?
    var category: String = "Other"
    var severity: String = "Ok"
    var imageUrl: String?

    var isLow: Bool { quantity <= 0.2 }
    var isExpiringSoon: Bool { (expiresIn ?? 999) <= 3 }

    /// 0.0 (just purchased) → 1.0 (expired). nil if no expiry data.
    var expiryProgress: Double? {
        guard let expiresAt else { return nil }
        let total = expiresAt.timeIntervalSince(purchaseDate)
        guard total > 0 else { return 1.0 }
        let elapsed = Date().timeIntervalSince(purchaseDate)
        return min(max(elapsed / total, 0), 1.0)
    }

    init(name: String, quantity: Double, unit: StockUnit, pricePerUnit: Double, totalPrice: Double, purchaseDate: Date, expiresIn: Int? = nil, category: String = "Other") {
        self.name = name
        self.quantity = quantity
        self.unit = unit
        self.pricePerUnit = pricePerUnit
        self.totalPrice = totalPrice
        self.purchaseDate = purchaseDate
        self.expiresIn = expiresIn
        self.category = category
    }

    init(from dto: APIClient.InventoryItemDTO) {
        self.backendId = dto.id
        self.productId = dto.product.id
        self.name = dto.product.name
        self.quantity = dto.remainingQuantity
        self.unit = StockUnit.from(backendUnit: dto.product.baseUnit)
        self.pricePerUnit = Double(dto.pricePerUnitCents) / 100.0
        self.totalPrice = Double(dto.pricePerUnitCents) * dto.remainingQuantity / 100.0
        self.category = dto.product.category
        self.severity = dto.severity
        self.imageUrl = dto.product.imageUrl

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.purchaseDate = isoFormatter.date(from: dto.receivedAt) ?? Date()

        if let expDate = isoFormatter.date(from: dto.expiresAt) {
            self.expiresAt = expDate
            self.expiresIn = Calendar.current.dateComponents([.day], from: Date(), to: expDate).day
        } else {
            self.expiresAt = nil
            self.expiresIn = nil
        }
    }

    enum StockUnit: String, CaseIterable, Identifiable {
        case kg, g, l, ml, pcs, bunch, pack
        var id: String { rawValue }

        /// Map backend unit strings like "kilogram", "piece", "liter", "gram" to our enum
        static func from(backendUnit: String) -> StockUnit {
            switch backendUnit.lowercased() {
            case "kilogram", "kg": return .kg
            case "gram", "g": return .g
            case "liter", "litre", "l": return .l
            case "milliliter", "ml": return .ml
            case "piece", "pcs", "unit": return .pcs
            case "bunch": return .bunch
            case "pack", "package": return .pack
            default: return .pcs
            }
        }

        var displayName: String {
            switch self {
            case .kg: return "kg"
            case .g: return "g"
            case .l: return "l"
            case .ml: return "ml"
            case .pcs: return "pcs"
            case .bunch: return "bunch"
            case .pack: return "pack"
            }
        }
    }
}

extension StockItem {
    /// Empty — real data comes from backend
    static let samples: [StockItem] = []
}

// MARK: MealPlanDay

struct Meal: Identifiable {
    let id = UUID()
    var type: MealType
    var recipe: Recipe?

    enum MealType: String, CaseIterable {
        case breakfast = "Breakfast"
        case lunch = "Lunch"
        case dinner = "Dinner"
    }
}

struct MealPlanDay: Identifiable {
    let id = UUID()
    var date: Date
    var meals: [Meal]
}

extension MealPlanDay {
    static var empty: MealPlanDay {
        MealPlanDay(
            date: .now,
            meals: Meal.MealType.allCases.map { Meal(type: $0, recipe: nil) }
        )
    }

    static var today: MealPlanDay {
        MealPlanDay(
            date: .now,
            meals: Meal.MealType.allCases.map { Meal(type: $0, recipe: nil) }
        )
    }
}
