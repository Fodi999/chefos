// MARK: - Presentation/Recipes/Common/RecipeHelpers.swift
// Shared helper functions for Recipes feature (DDD refactoring)

import SwiftUI

// MARK: - Category icon by product category string

func stockCategoryIcon(_ category: String) -> String {
    let lower = category.lowercased()
    if lower.contains("veget") || lower.contains("fruit") || lower.contains("herb") { return "leaf.fill" }
    if lower.contains("meat") || lower.contains("fish") || lower.contains("seafood") { return "fork.knife" }
    if lower.contains("dairy") || lower.contains("milk") || lower.contains("cheese") { return "cup.and.saucer.fill" }
    if lower.contains("dry") || lower.contains("grain") || lower.contains("cereal") || lower.contains("pasta") { return "shippingbox.fill" }
    if lower.contains("condiment") || lower.contains("sauce") || lower.contains("oil") || lower.contains("spice") { return "drop.fill" }
    return "tray.fill"
}

// MARK: - Icon for recipe tag

func recipeTagIcon(_ tag: String) -> String {
    switch tag {
    case "uses_expiring_ingredients": return "clock.badge.exclamationmark"
    case "high_protein":              return "bolt.fill"
    case "all_ingredients_available": return "checkmark.circle.fill"
    case "budget_friendly":           return "dollarsign.circle.fill"
    case "low_calorie":               return "flame"
    case "high_calorie":              return "flame.fill"
    case "vegetarian":                return "leaf.fill"
    case "vegan":                     return "leaf"
    case "gluten_free":               return "xmark.circle"
    case "dairy_free":                return "drop.triangle"
    case "quick":                     return "hare.fill"
    case "seasonal":                  return "sun.max.fill"
    case "spicy":                     return "thermometer.high"
    case "high_fiber":                return "chart.bar.fill"
    case "low_carb":                  return "minus.circle"
    default:                          return "tag"
    }
}

// MARK: - Localize recipe reason key

func localizeRecipeReason(_ reason: String, l10n: LocalizationService) -> String {
    switch reason {
    case "uses_expiring_ingredients": return l10n.t("cook.reason.expiring")
    case "high_protein":             return l10n.t("cook.reason.protein")
    case "all_ingredients_available":return l10n.t("cook.reason.allAvailable")
    case "budget_friendly":          return l10n.t("cook.reason.budget")
    case "fits_goal":                return l10n.t("cook.reason.fitsGoal")
    case "uses_inventory":           return l10n.t("cook.reason.usesInventory")
    default: return reason.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

// MARK: - Localize tag

func localizeRecipeTag(_ tag: String, l10n: LocalizationService) -> String {
    let key = "tag.\(tag)"
    let result = l10n.t(key)
    return result == key ? tag.replacingOccurrences(of: "_", with: " ").capitalized : result
}

// MARK: - Localize allergen

func localizeAllergen(_ allergen: String, l10n: LocalizationService) -> String {
    let key = "allergen.\(allergen.lowercased())"
    let result = l10n.t(key)
    return result == key ? allergen.capitalized : result
}

// MARK: - Localize dish type

func localizeRecipeDishType(_ type: String, l10n: LocalizationService) -> String {
    let key = "dishType.\(type)"
    let result = l10n.t(key)
    return result == key ? type.replacingOccurrences(of: "_", with: " ").capitalized : result
}

// MARK: - Localize complexity

func localizeRecipeComplexity(_ c: String, l10n: LocalizationService) -> String {
    let key = "complexity.\(c)"
    let result = l10n.t(key)
    return result == key ? c.capitalized : result
}
