
//
//  CalendarDayCell.swift
//  ChefOS — Presentation/Plan/Components
//
//  Single day tile in the horizontal calendar strip.
//  Extracted from PlanView.swift (DDD refactor).
//

import SwiftUI

// MARK: - CalendarDayCell

struct CalendarDayCell: View {
    let dayLetter: String
    let dayNumber: String
    let isSelected: Bool
    let isToday: Bool
    let hasMeals: Bool

    var body: some View {
        VStack(spacing: 6) {
            Text(dayLetter)
                .appStyle(.caption2)
                .foregroundStyle(isSelected ? AppColors.textPrimary : AppColors.textSecondary)

            Text(dayNumber)
                .appStyle(.title2)
                .foregroundStyle(isSelected ? AppColors.textPrimary : AppColors.textPrimary)

            Circle()
                .fill(hasMeals ? SemanticColors.meal(.breakfast) : .clear)
                .frame(width: 5, height: 5)
        }
        .frame(width: 48, height: 72)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                    .fill(AppColors.primary)
            } else if isToday {
                RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                    .strokeBorder(SemanticColors.meal(.breakfast).opacity(0.4), lineWidth: 1)
            }
        }
        .contentShape(Rectangle())
    }
}
