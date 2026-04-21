//
//  MacroBar.swift
//  ChefOS — DesignSystem
//
//  Nutrition macro strip: kcal / protein / fat / carbs.
//  Usage: MacroBar(kcal: 420, protein: 32, fat: 12, carbs: 48)
//

import SwiftUI

struct MacroBar: View {
    let kcal: Int
    let protein: Double
    let fat: Double
    let carbs: Double

    var body: some View {
        HStack(spacing: Spacing.xs) {
            macroChip(value: "\(kcal)", label: "ккал", color: AppColors.accent)
            macroChip(value: "\(Int(protein))г", label: "белок", color: AppColors.primary)
            macroChip(value: "\(Int(fat))г", label: "жир", color: AppColors.warning)
            macroChip(value: "\(Int(carbs))г", label: "углев", color: AppColors.success)
        }
    }

    private func macroChip(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(Typography.font(for: .caption))
                .fontWeight(.semibold)
                .foregroundColor(color)
            Text(label)
                .font(Typography.font(for: .micro))
                .foregroundColor(AppColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xxs)
        .background(color.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: Radius.xs, style: .continuous))
    }
}
