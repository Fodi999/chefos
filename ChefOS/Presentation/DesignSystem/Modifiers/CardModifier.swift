//
//  CardModifier.swift
//  ChefOS — DesignSystem
//
//  Solid card surface modifier.
//  Usage: .appCard() or .appCard(cornerRadius: Radius.sm)
//

import SwiftUI

struct CardModifier: ViewModifier {
    var cornerRadius: CGFloat = Radius.md
    var padding: CGFloat = Spacing.sm

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(AppColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .applyShadow(Shadows.card)
    }
}

extension View {
    func appCard(cornerRadius: CGFloat = Radius.md, padding: CGFloat = Spacing.sm) -> some View {
        modifier(CardModifier(cornerRadius: cornerRadius, padding: padding))
    }
}
