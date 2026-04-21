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
                    .stroke(AppColors.glassStroke, lineWidth: 0.5)
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .applyShadow(Shadows.card)
    }

    @ViewBuilder
    private var background: some View {
        switch style {
        case .glass:
            AppColors.surface
        case .solid:
            AppColors.surface
        case .elevated:
            AppColors.surfaceRaised
        }
    }
}
