
//
//  SemanticColors.swift
//  ChefOS — DesignSystem
//
//  Семантические цвета. Используй роль, а не raw Color.
//
//  ❌ НЕ ДЕЛАЙ: .foregroundStyle(Color.orange)
//  ✅ ДЕЛАЙ:    .foregroundStyle(SemanticColors.nutrient(.calories))
//
//  Архитектура:
//    SemanticColors.nutrient(.calories)   — нутриенты
//    SemanticColors.meal(.breakfast)      — приёмы пищи
//    SemanticColors.state(.danger)        — состояния UI
//    SemanticColors.tag(.category)        — теги / пилюли
//

import SwiftUI

// MARK: - Domain types

/// Типы нутриентов
enum NutrientType { case calories, protein, fat, carbs }

/// Типы приёмов пищи
enum MealType { case breakfast, lunch, dinner }

/// Состояния UI
enum StateType { case success, warning, danger, neutral, budget }

/// Категории тегов
enum TagType { case category, trend, allergen }

// MARK: - SemanticColors

enum SemanticColors {

    // ── Nutrients ──────────────────────────────────────────────────
    static func nutrient(_ type: NutrientType) -> Color {
        switch type {
        case .calories: return .orange
        case .protein:  return .cyan
        case .fat:      return .yellow
        case .carbs:    return .green
        }
    }

    // ── Meal types ─────────────────────────────────────────────────
    static func meal(_ type: MealType) -> Color {
        switch type {
        case .breakfast: return .orange
        case .lunch:     return .yellow
        case .dinner:    return .indigo
        }
    }

    // ── UI States ──────────────────────────────────────────────────
    static func state(_ type: StateType) -> Color {
        switch type {
        case .success:  return AppColors.success
        case .warning:  return AppColors.warning
        case .danger:   return AppColors.danger
        case .neutral:  return AppColors.textSecondary
        case .budget:   return AppColors.success   // within budget = green
        }
    }

    // ── Tags ───────────────────────────────────────────────────────
    static func tag(_ type: TagType) -> Color {
        switch type {
        case .category: return .cyan
        case .trend:    return .purple
        case .allergen: return AppColors.danger
        }
    }

    // MARK: - Flat aliases (deprecated — migrate to structured calls)
    //
    //  These exist only to keep old call sites compiling.
    //  They will be removed in the next cleanup pass.
    //
    //  Migration guide:
    //    .success  → SemanticColors.state(.success)
    //    .calories → SemanticColors.nutrient(.calories)
    //    .breakfast → SemanticColors.meal(.breakfast)
    //    .tagDish  → SemanticColors.tag(.category)

    @available(*, deprecated, message: "Use SemanticColors.state(.success)")
    static let success   = state(.success)
    @available(*, deprecated, message: "Use SemanticColors.state(.warning)")
    static let warning   = state(.warning)
    @available(*, deprecated, message: "Use SemanticColors.state(.danger)")
    static let danger    = state(.danger)
    @available(*, deprecated, message: "Use SemanticColors.state(.neutral)")
    static let neutral   = state(.neutral)
    @available(*, deprecated, message: "Use SemanticColors.state(.budget)")
    static let budgetOk  = state(.budget)
    @available(*, deprecated, message: "Use SemanticColors.state(.danger)")
    static let budgetOver = state(.danger)

    @available(*, deprecated, message: "Use SemanticColors.nutrient(.calories)")
    static let calories = nutrient(.calories)
    @available(*, deprecated, message: "Use SemanticColors.nutrient(.protein)")
    static let protein  = nutrient(.protein)
    @available(*, deprecated, message: "Use SemanticColors.nutrient(.fat)")
    static let fat      = nutrient(.fat)
    @available(*, deprecated, message: "Use SemanticColors.nutrient(.carbs)")
    static let carbs    = nutrient(.carbs)

    @available(*, deprecated, message: "Use SemanticColors.meal(.breakfast)")
    static let breakfast = meal(.breakfast)
    @available(*, deprecated, message: "Use SemanticColors.meal(.lunch)")
    static let lunch     = meal(.lunch)
    @available(*, deprecated, message: "Use SemanticColors.meal(.dinner)")
    static let dinner    = meal(.dinner)

    @available(*, deprecated, message: "Use SemanticColors.tag(.category)")
    static let tagDish    = tag(.category)
    @available(*, deprecated, message: "Use SemanticColors.tag(.trend)")
    static let tagTrend   = tag(.trend)
    @available(*, deprecated, message: "Use SemanticColors.tag(.allergen)")
    static let tagAllergen = tag(.allergen)
}
