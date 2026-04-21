//
//  GlassModifier.swift
//  ChefOS — DesignSystem
//
//  The signature 2026 glass card style.
//  Usage: .glassCard() or .glassCard(cornerRadius: Radius.lg)
//

import SwiftUI

// MARK: - Glass Card Modifier

struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat = Radius.md

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial.opacity(0.6))
            }
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(AppColors.glassStroke, lineWidth: 1)
            )
            .applyShadow(Shadows.card)
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = Radius.md) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius))
    }
}

// MARK: - Ambient Glow Modifier

struct AmbientGlow: ViewModifier {
    var color: Color = AppColors.primaryGlow
    var radius: CGFloat = 30

    func body(content: Content) -> some View {
        content
            .background(
                color
                    .blur(radius: radius)
                    .opacity(0.5)
            )
    }
}

extension View {
    func ambientGlow(color: Color = AppColors.primaryGlow, radius: CGFloat = 30) -> some View {
        modifier(AmbientGlow(color: color, radius: radius))
    }
}
