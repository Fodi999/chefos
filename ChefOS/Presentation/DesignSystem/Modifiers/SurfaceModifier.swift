
//
//  SurfaceModifier.swift
//  ChefOS — DesignSystem
//
//  Surface system: The standardized way to set backgrounds for cards and screens.
//  Optimized for Real Product (Apple HIG) - Zero visual noise.
//

import SwiftUI

// MARK: - Tag Style (semantic pill/badge backgrounds)

enum TagStyle {
    case calories, protein, fat, carbs
    case success, warning, danger, neutral, budget
    case category, trend, allergen
    case breakfast, lunch, dinner

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
    case screen
    case card
    case elevated
    case tag(TagStyle)
    
    // Legacy mapping (migrated to standard card for noise reduction)
    static let glass = Surface.card 
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
                .applyShadow(Shadows.card)

        case .elevated:
            content
                .background(
                    AppColors.surfaceRaised,
                    in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                )
                .applyShadow(Shadows.intense)

        case .tag(let style):
            let c = style.color
            content
                .background(c.opacity(0.12), // Solid but subtle highlight
                             in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }
}

// MARK: - View Extension

extension View {
    /// Applies a semantic surface to the view.
    func surface(_ type: Surface, cornerRadius: CGFloat = Radius.md) -> some View {
        modifier(SurfaceViewModifier(surface: type, cornerRadius: cornerRadius))
    }
}
