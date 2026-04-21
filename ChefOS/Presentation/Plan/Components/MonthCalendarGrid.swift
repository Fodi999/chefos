//
//  MonthCalendarGrid.swift
//  ChefOS — Presentation/Plan/Components
//
//  iOS 26-style month calendar grid. Shows 6 × 7 days with meal-dot
//  indicators and today/selected highlights. Purely presentational —
//  accepts data via the model and forwards taps through a callback.
//

import SwiftUI

// MARK: - Month Day Cell Model

struct MonthDayCellModel: Identifiable {
    let id = UUID()
    let date: Date
    let dayNumber: String
    let isToday: Bool
    let isSelected: Bool
    let isInCurrentMonth: Bool
    let mealDots: Int          // 0…3, matches breakfast/lunch/dinner filled count
}

// MARK: - Grid View

struct MonthCalendarGrid: View {
    let monthTitle: String
    let weekdaySymbols: [String]
    let days: [MonthDayCellModel]
    let onPrev: () -> Void
    let onNext: () -> Void
    let onSelect: (Date) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        VStack(spacing: 14) {
            // Header — month title + navigation
            HStack(spacing: 16) {
                Button(action: onPrev) {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AppColors.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(AppColors.surfaceRaised, in: Circle())
                }
                .buttonStyle(.plain)

                Spacer()

                Text(monthTitle)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppColors.textPrimary)
                    .contentTransition(.numericText())

                Spacer()

                Button(action: onNext) {
                    Image(systemName: "chevron.right")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AppColors.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(AppColors.surfaceRaised, in: Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)

            // Weekday symbols row
            HStack(spacing: 4) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, s in
                    Text(s)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppColors.textSecondary.opacity(0.7))
                        .frame(maxWidth: .infinity)
                }
            }

            // Day grid
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(days) { day in
                    Button {
                        onSelect(day.date)
                    } label: {
                        MonthDayCell(model: day)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .productCard(cornerRadius: 18)
    }
}

// MARK: - Single Day Cell

private struct MonthDayCell: View {
    let model: MonthDayCellModel

    var body: some View {
        VStack(spacing: 3) {
            Text(model.dayNumber)
                .font(.system(size: 15, weight: model.isToday ? .bold : .medium, design: .rounded))
                .foregroundStyle(foregroundColor)

            // Meal dots — up to 3 small circles
            HStack(spacing: 2) {
                ForEach(0..<3, id: \.self) { idx in
                    Circle()
                        .fill(idx < model.mealDots
                              ? (model.isSelected ? Color.white : Color.orange)
                              : Color.clear)
                        .frame(width: 4, height: 4)
                }
            }
            .frame(height: 6)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .background {
            if model.isSelected {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.orange)
            } else if model.isToday {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.orange.opacity(0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color.orange.opacity(0.4), lineWidth: 1)
                    )
            }
        }
        .opacity(model.isInCurrentMonth ? 1 : 0.3)
        .contentShape(Rectangle())
    }

    private var foregroundColor: Color {
        if model.isSelected { return .white }
        if model.isToday { return .orange }
        return AppColors.textPrimary
    }
}
