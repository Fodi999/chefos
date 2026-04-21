//
//  AppCard.swift
//  ChefOS — DesignSystem
//
//  Universal card container. Replace all inline .padding/.background/.cornerRadius.
//  Usage:
//    AppCard { Text("Hello") }
//    AppCard(style: .glass) { Text("Hello") }
//

import SwiftUI

enum AppCardStyle {
    case solid      // опaque surface
    case glass      // ultraThinMaterial glass
    case elevated   // deeper shadow
}

struct AppCard<Content: View>: View {
    let style: AppCardStyle
    let cornerRadius: CGFloat
    let content: Content

    init(
        style: AppCardStyle = .solid,
        cornerRadius: CGFloat = Radius.md,
        @ViewBuilder content: () -> Content
    ) {
        self.style = style
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        content
            .padding(Spacing.sm)
            .background { background }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(AppColors.glassStroke, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .applyShadow(style == .elevated ? Shadows.intense : Shadows.card)
    }

    @ViewBuilder
    private var background: some View {
        switch style {
        case .solid:
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(AppColors.surface)
        case .glass:
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial.opacity(0.6))
        case .elevated:
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(AppColors.surfaceRaised)
        }
    }
}
