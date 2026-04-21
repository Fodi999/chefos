//
//  TagView.swift
//  ChefOS — DesignSystem
//
//  Pill-shaped tag for labels, allergens, dietary flags.
//  Usage: TagView("Веган") or TagView("Глютен", color: AppColors.danger)
//

import SwiftUI

struct TagView: View {
    let text: String
    var color: Color = AppColors.primary
    var icon: String? = nil

    var body: some View {
        HStack(spacing: Spacing.xxs) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .medium))
            }
            Text(text)
                .font(Typography.font(for: .micro))
                .fontWeight(.medium)
        }
        .foregroundColor(color)
        .padding(.horizontal, Spacing.xs)
        .padding(.vertical, 4)
        .background(color.opacity(0.15))
        .clipShape(Capsule())
    }
}

// MARK: - Tag Row (wrapping)

struct TagRow: View {
    let tags: [String]
    var color: Color = AppColors.primary

    var body: some View {
        // Simple horizontal scroll for tags
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.xxs) {
                ForEach(tags, id: \.self) { tag in
                    TagView(text: tag, color: color)
                }
            }
            .padding(.horizontal, 1)
        }
    }
}
