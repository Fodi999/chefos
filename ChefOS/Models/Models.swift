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
        let l10n = LocalizationService.shared
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
    static let samples: [Recipe] = [
        Recipe(
            title: "Tomato Basil Pasta",
            calories: 450,
            protein: 18,
            servings: 2,
            ingredients: ["Pasta", "Tomatoes", "Basil", "Parmesan", "Olive oil", "Garlic"],
            recipeIngredients: [
                .init(name: "Pasta", quantity: 200, unit: "g"),
                .init(name: "Tomatoes", quantity: 300, unit: "g"),
                .init(name: "Basil", quantity: 1, unit: "bunch"),
                .init(name: "Parmesan", quantity: 30, unit: "g"),
                .init(name: "Olive oil", quantity: 20, unit: "ml"),
                .init(name: "Garlic", quantity: 2, unit: "pcs"),
            ],
            steps: [
                "Boil pasta according to package directions.",
                "Sauté garlic in olive oil until fragrant.",
                "Add diced tomatoes and cook for 5 minutes.",
                "Toss pasta with sauce, top with basil and parmesan."
            ],
            estimatedCost: 8.20
        ),
        Recipe(
            title: "Greek Salad",
            calories: 280,
            protein: 12,
            servings: 2,
            ingredients: ["Cucumber", "Tomato", "Red onion", "Feta", "Olives", "Olive oil"],
            recipeIngredients: [
                .init(name: "Cucumber", quantity: 1, unit: "pcs"),
                .init(name: "Tomatoes", quantity: 200, unit: "g"),
                .init(name: "Red onion", quantity: 1, unit: "pcs"),
                .init(name: "Feta", quantity: 100, unit: "g"),
                .init(name: "Olives", quantity: 50, unit: "g"),
                .init(name: "Olive oil", quantity: 15, unit: "ml"),
            ],
            steps: [
                "Chop all vegetables into bite-size pieces.",
                "Combine in a bowl.",
                "Add crumbled feta and olives.",
                "Drizzle with olive oil and season."
            ],
            estimatedCost: 6.50
        ),
        Recipe(
            title: "Chicken Stir-Fry",
            calories: 520,
            protein: 42,
            servings: 2,
            ingredients: ["Chicken breast", "Broccoli", "Bell pepper", "Soy sauce", "Rice", "Ginger"],
            recipeIngredients: [
                .init(name: "Chicken breast", quantity: 400, unit: "g"),
                .init(name: "Broccoli", quantity: 200, unit: "g"),
                .init(name: "Bell pepper", quantity: 2, unit: "pcs"),
                .init(name: "Soy sauce", quantity: 30, unit: "ml"),
                .init(name: "Rice", quantity: 200, unit: "g"),
                .init(name: "Ginger", quantity: 10, unit: "g"),
            ],
            steps: [
                "Cook rice according to package directions.",
                "Slice chicken and vegetables.",
                "Stir-fry chicken until cooked through.",
                "Add vegetables and soy sauce, cook 3 minutes.",
                "Serve over rice."
            ],
            estimatedCost: 11.40
        )
    ]
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
    var name: String
    var quantity: Double
    var unit: StockUnit
    var pricePerUnit: Double
    var totalPrice: Double
    var purchaseDate: Date
    var store: String
    var expiresIn: Int?
    var category: StockCategory = .other

    var isLow: Bool { quantity <= 0.2 }
    var isExpiringSoon: Bool { (expiresIn ?? 999) <= 3 }

    enum StockUnit: String, CaseIterable, Identifiable {
        case kg, g, l, ml, pcs, bunch, pack
        var id: String { rawValue }
    }

    enum StockCategory: String, CaseIterable, Identifiable {
        case vegetables = "Vegetables"
        case meat = "Meat & Fish"
        case dairy = "Dairy"
        case dryGoods = "Dry Goods"
        case condiments = "Condiments"
        case other = "Other"
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .vegetables: return "leaf.fill"
            case .meat: return "fork.knife"
            case .dairy: return "cup.and.saucer.fill"
            case .dryGoods: return "shippingbox.fill"
            case .condiments: return "drop.fill"
            case .other: return "tray.fill"
            }
        }
    }
}

extension StockItem {
    static let samples: [StockItem] = [
        StockItem(name: "Tomatoes", quantity: 2.0, unit: .kg, pricePerUnit: 6.0, totalPrice: 12.0, purchaseDate: .now.addingTimeInterval(-86400), store: "Biedronka", expiresIn: 5, category: .vegetables),
        StockItem(name: "Chicken breast", quantity: 1.5, unit: .kg, pricePerUnit: 18.7, totalPrice: 28.0, purchaseDate: .now.addingTimeInterval(-86400 * 2), store: "Lidl", expiresIn: 3, category: .meat),
        StockItem(name: "Basil", quantity: 3, unit: .bunch, pricePerUnit: 3.0, totalPrice: 9.0, purchaseDate: .now, store: "Żabka", expiresIn: 2, category: .vegetables),
        StockItem(name: "Pasta", quantity: 2, unit: .pack, pricePerUnit: 4.5, totalPrice: 9.0, purchaseDate: .now.addingTimeInterval(-86400 * 5), store: "Biedronka", expiresIn: nil, category: .dryGoods),
        StockItem(name: "Parmesan", quantity: 0.3, unit: .kg, pricePerUnit: 45.0, totalPrice: 13.5, purchaseDate: .now.addingTimeInterval(-86400 * 3), store: "Lidl", expiresIn: 14, category: .dairy),
        StockItem(name: "Olive oil", quantity: 0.5, unit: .l, pricePerUnit: 24.0, totalPrice: 12.0, purchaseDate: .now.addingTimeInterval(-86400 * 10), store: "Biedronka", expiresIn: nil, category: .condiments),
        StockItem(name: "Garlic", quantity: 4, unit: .pcs, pricePerUnit: 1.2, totalPrice: 4.8, purchaseDate: .now.addingTimeInterval(-86400 * 4), store: "Biedronka", expiresIn: 20, category: .vegetables),
        StockItem(name: "Cucumber", quantity: 2, unit: .pcs, pricePerUnit: 2.5, totalPrice: 5.0, purchaseDate: .now, store: "Żabka", expiresIn: 6, category: .vegetables),
        StockItem(name: "Feta", quantity: 0.4, unit: .kg, pricePerUnit: 32.0, totalPrice: 12.8, purchaseDate: .now.addingTimeInterval(-86400), store: "Lidl", expiresIn: 10, category: .dairy),
        StockItem(name: "Olives", quantity: 1, unit: .pack, pricePerUnit: 8.5, totalPrice: 8.5, purchaseDate: .now.addingTimeInterval(-86400 * 2), store: "Biedronka", expiresIn: nil, category: .condiments),
        StockItem(name: "Soy sauce", quantity: 0.3, unit: .l, pricePerUnit: 12.0, totalPrice: 3.6, purchaseDate: .now.addingTimeInterval(-86400 * 7), store: "Lidl", expiresIn: nil, category: .condiments),
        StockItem(name: "Rice", quantity: 1, unit: .kg, pricePerUnit: 5.5, totalPrice: 5.5, purchaseDate: .now.addingTimeInterval(-86400 * 6), store: "Biedronka", expiresIn: nil, category: .dryGoods),
        StockItem(name: "Broccoli", quantity: 0.5, unit: .kg, pricePerUnit: 8.0, totalPrice: 4.0, purchaseDate: .now, store: "Lidl", expiresIn: 4, category: .vegetables),
        StockItem(name: "Bell pepper", quantity: 3, unit: .pcs, pricePerUnit: 3.0, totalPrice: 9.0, purchaseDate: .now.addingTimeInterval(-86400), store: "Biedronka", expiresIn: 7, category: .vegetables),
        StockItem(name: "Ginger", quantity: 0.1, unit: .kg, pricePerUnit: 30.0, totalPrice: 3.0, purchaseDate: .now.addingTimeInterval(-86400 * 3), store: "Żabka", expiresIn: 12, category: .vegetables),
    ]
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
            meals: [
                Meal(type: .breakfast, recipe: nil),
                Meal(type: .lunch, recipe: Recipe.samples[0]),
                Meal(type: .dinner, recipe: nil)
            ]
        )
    }
}
