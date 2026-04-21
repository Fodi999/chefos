//
//  Shadows.swift
//  ChefOS — DesignSystem
//
//  All shadow presets in one place.
//  Usage: Shadows.card.apply(to: view)
//

import SwiftUI

struct ShadowStyle {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

enum Shadows {
    static let card    = ShadowStyle(color: .black.opacity(0.30), radius: 20, x: 0, y: 10)
    static let subtle  = ShadowStyle(color: .black.opacity(0.15), radius: 8,  x: 0, y: 4)
    static let intense = ShadowStyle(color: .black.opacity(0.50), radius: 32, x: 0, y: 16)
    static let glow    = ShadowStyle(color: AppColors.primary.opacity(0.35), radius: 24, x: 0, y: 0)
}

extension View {
    func applyShadow(_ style: ShadowStyle) -> some View {
        self.shadow(color: style.color, radius: style.radius, x: style.x, y: style.y)
    }
}
