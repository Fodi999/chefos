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

// MARK: RecipeIngredient

struct RecipeIngredient: Identifiable {
    let id = UUID()
    var name: String           // must fuzzy-match StockItem.name
    var quantity: Double
    var unit: String           // "g", "kg", "ml", "pcs", etc.
}

// MARK: Recipe

struct Recipe: Identifiable {
    let id = UUID()
    var title: String
    var calories: Int
    var protein: Int = 0
    var servings: Int = 2
    var ingredients: [String]            // kept for backward compat
    var recipeIngredients: [RecipeIngredient] = []
    var steps: [String]
    var imageName: String? = nil
    var estimatedCost: Double = 0        // zł total
    var costPerServing: Double { servings > 0 ? estimatedCost / Double(servings) : estimatedCost }
}

extension Recipe {
    /// Bridge: create a Recipe from a backend SuggestedDish
    init(from dish: APIClient.SuggestedDish) {
        self.init(
            title: dish.displayName ?? dish.dishNameLocal ?? dish.dishName,
            calories: dish.perServingKcal,
            protein: Int(dish.perServingProteinG),
            servings: max(dish.servings, 1),
            ingredients: dish.ingredients.map { $0.name },
            recipeIngredients: dish.ingredients.map { ing in
                RecipeIngredient(name: ing.name, quantity: Double(ing.grossG), unit: "g")
            },
            steps: dish.steps.map { s in
                var line = s.text
                if let t = s.timeMin { line += " (\(t) min)" }
                if let temp = s.tempC { line += " \(temp)°C" }
                return line
            },
            estimatedCost: Double(dish.insight.estimatedCostCents) / 100.0
        )
    }

    /// Empty fallback — no hardcoded demos
    static let samples: [Recipe] = []
}

// MARK: Message

enum MessageContent {
    case text(String)
    case recipeCard(Recipe)
    case image(UIImage)
}

struct Message: Identifiable {
    let id = UUID()
    let content: MessageContent
    let isFromUser: Bool
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
