
//
//  SurfaceModifier.swift
//  ChefOS — DesignSystem
//
//  Surface system: единственный способ задавать фон карточкам и экранам.
//
//  ❌ НЕ ДЕЛАЙ: .background(Color.black).cornerRadius(18)
//  ❌ НЕ ДЕЛАЙ: .surface(.interactive(someColor))   ← цвет утекает в Features
//  ✅ ДЕЛАЙ:    .surface(.card)
//  ✅ ДЕЛАЙ:    .surface(.tag(.calories))
//  ✅ ДЕЛАЙ:    .surface(.tag(.state(.danger)))
//

import SwiftUI

// MARK: - Tag Style (semantic pill/badge backgrounds)
//
//  Плоский enum — все кейсы на одном уровне для удобного чтения кода.
//  Цвет каждого кейса закреплён в DesignSystem, Features его не знают.

enum TagStyle {
    // Нутриенты
    case calories, protein, fat, carbs
    // Состояния UI
    case success, warning, danger, neutral, budget
    // Типы контента
    case category, trend, allergen
    // Приёмы пищи
    case breakfast, lunch, dinner

    /// Цвет, соответствующий этому тегу. Только DesignSystem знает маппинг.
    var color: Color {
        switch self {
        case .calories:  return SemanticColors.nutrient(.calories)
        case .protein:   return SemanticColors.nutrient(.protein)
        case .fat:       return SemanticColors.nutrient(.fat)
        case .carbs:     return SemanticColors.nutrient(.carbs)
        case .success:   return SemanticColors.state(.success)
        case .warning:   return SemanticColors.state(.warning)
        case .danger:    return SemanticColors.state(.danger)
        case .neutral:   return SemanticColors.state(.neutral)
        case .budget:    return SemanticColors.state(.budget)
        case .category:  return SemanticColors.tag(.category)
        case .trend:     return SemanticColors.tag(.trend)
        case .allergen:  return SemanticColors.tag(.allergen)
        case .breakfast: return SemanticColors.meal(.breakfast)
        case .lunch:     return SemanticColors.meal(.lunch)
        case .dinner:    return SemanticColors.meal(.dinner)
        }
    }
}

// MARK: - Surface Levels

enum Surface {
    /// Фон всего экрана
    case screen
    /// Карточка первого уровня
    case card
    /// Карточка с тенью (raised panel)
    case elevated
    /// Стеклянная поверхность
    case glass
    /// Семантический тег / пилюля / бейдж
    ///
    /// Usage: `.surface(.tag(.calories))`, `.surface(.tag(.danger))`
    case tag(TagStyle)
}

// MARK: - Surface ViewModifier

struct SurfaceViewModifier: ViewModifier {
    let surface: Surface
    var cornerRadius: CGFloat = Radius.md

    func body(content: Content) -> some View {
        switch surface {
        case .screen:
            content
                .background(AppColors.background)

        case .card:
            content
                .background(
                    AppColors.surface,
                    in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                )

        case .elevated:
            content
                .background(
                    AppColors.surfaceRaised,
                    in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                )
                .shadow(color: .black.opacity(0.35), radius: 12, y: 6)

        case .glass:
            content
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(AppColors.glassFill)
                        .overlay(
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .strokeBorder(AppColors.glassStroke, lineWidth: 1)
                        )
                )

        case .tag(let style):
            let c = style.color
            content
                .background(c.opacity(0.10),
                             in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(c.opacity(0.18), lineWidth: 1)
                )
        }
    }
}

// MARK: - View Extension

extension View {
    /// Applies a semantic surface to the view.
    ///
    /// ```swift
    /// VStack { ... }.surface(.card)
    /// Text("418 kcal").surface(.tag(.calories), cornerRadius: Radius.full)
    /// ```
    func surface(_ type: Surface, cornerRadius: CGFloat = Radius.md) -> some View {
        modifier(SurfaceViewModifier(surface: type, cornerRadius: cornerRadius))
    }
}
