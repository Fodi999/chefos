//
//  GlassModifier.swift
//  ChefOS — DesignSystem
//
//  Real Product: Standardized UI surfaces based on Apple HIG.
//  No visual noise (no glows, no gradients).
//

import SwiftUI

// MARK: - Product Card Modifier

struct ProductCard: ViewModifier {
    var cornerRadius: CGFloat = Radius.md

    func body(content: Content) -> some View {
        content
            .background(AppColors.surface, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .applyShadow(Shadows.card)
    }
}

extension View {
    /// Applies a standard HIG-compliant card style.
    func glassCard(cornerRadius: CGFloat = Radius.md) -> some View {
        modifier(ProductCard(cornerRadius: cornerRadius))
    }
    
    /// Legacy alias for glassCard
    func productCard(cornerRadius: CGFloat = Radius.md) -> some View {
         modifier(ProductCard(cornerRadius: cornerRadius))
    }
}

// MARK: - No-Op Modifiers (Removed Noise)

struct NoNoiseGlow: ViewModifier {
    func body(content: Content) -> some View {
        content // NO noise allowed
    }
}

extension View {
    /// Removed: Ambient glow is no longer part of the product design.
    func ambientGlow(color: Color = .clear, radius: CGFloat = 0) -> some View {
        modifier(NoNoiseGlow())
    }
}
