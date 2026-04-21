
//
//  PlanSummaryCard.swift
//  ChefOS — Presentation/Plan/Components
//
//  Карточка нутриентов + бюджет за день.
//  Принимает чистые числа — не знаёт ViewModel.
//

import SwiftUI

// MARK: - Plan Summary Model (pure display data)

struct PlanSummaryModel {
    let calories:      Int
    let calorieTarget: Int
    let protein:       Int
    let proteinTarget: Int
    let cost:          Double
    let budgetTarget:  Double
    let currency:      String
    let statusText:    String
    let statusColor:   Color

    var calorieProgress: Double { target(calories, of: calorieTarget) }
    var proteinProgress: Double { target(protein, of: proteinTarget) }
    var costProgress:    Double { target(Int(cost), of: Int(budgetTarget)) }

    private func target(_ value: Int, of total: Int) -> Double {
        guard total > 0 else { return 0 }
        return min(Double(value) / Double(total), 1.0)
    }
}

// MARK: - PlanSummaryCard

struct PlanSummaryCard: View {
    let summary: PlanSummaryModel

    private var budgetColor: Color {
        summary.cost > summary.budgetTarget
            ? SemanticColors.state(.danger)
            : SemanticColors.state(.budget)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Rings row
            GroupCard {
                StatRingRow(stats: [
                    .init(
                        value: summary.calories,
                        target: summary.calorieTarget,
                        unit: "kcal",
                        label: "Calories",
                        accent: SemanticColors.nutrient(.calories),
                        lineWidth: 10   // primary — thickest
                    ),
                    .init(
                        value: summary.protein,
                        target: summary.proteinTarget,
                        unit: "g",
                        label: "Protein",
                        accent: SemanticColors.nutrient(.protein),
                        lineWidth: 6    // secondary
                    ),
                    .init(
                        value: Int(summary.cost),
                        target: Int(summary.budgetTarget),
                        unit: summary.currency,
                        label: "Budget",
                        accent: budgetColor,
                        lineWidth: 6    // secondary
                    ),
                ])
            }

            // Status line
            if !summary.statusText.isEmpty {
                Text(summary.statusText)
                    .appStyle(.caption)
                    .foregroundStyle(summary.statusColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Spacing.xs)
                    .padding(.top, 6)
            }
        }
    }
}
