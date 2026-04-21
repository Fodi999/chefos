//
//  Shadows.swift
//  ChefOS — DesignSystem
//
//  Real Product: Zero Noise. 
//  Shadows are removed or set to HIG standard defaults.
//

import SwiftUI

struct ShadowStyle {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

enum Shadows {
    /// Standard card shadow (very subtle in dark mode)
    static let card    = ShadowStyle(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    
    static let subtle  = ShadowStyle(color: .black.opacity(0.05), radius: 2,  x: 0, y: 1)
    
    static let intense = ShadowStyle(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
    
    static let glow    = none // NO glow allowed
    
    static let none    = ShadowStyle(color: .clear, radius: 0, x: 0, y: 0)
}

extension View {
    func applyShadow(_ style: ShadowStyle) -> some View {
        self.shadow(color: style.color, radius: style.radius, x: style.x, y: style.y)
    }
}
