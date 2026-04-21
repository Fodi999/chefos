
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

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 16) {
                PlanProgressRing(
                    progress: summary.calorieProgress,
                    icon: "flame.fill",
                    current: summary.calories,
                    target: summary.calorieTarget,
                    unit: "kcal",
                    color: SemanticColors.nutrient(.calories)
                )
                PlanProgressRing(
                    progress: summary.proteinProgress,
                    icon: "bolt.fill",
                    current: summary.protein,
                    target: summary.proteinTarget,
                    unit: "g protein",
                    color: SemanticColors.nutrient(.protein)
                )
                CostRing(
                    progress: summary.costProgress,
                    current: summary.cost,
                    target: summary.budgetTarget,
                    color: summary.cost > summary.budgetTarget
                        ? SemanticColors.state(.danger)
                        : SemanticColors.state(.budget),
                    currency: summary.currency
                )
            }

            // Status line
            Text(summary.statusText)
                .appStyle(.caption)
                .foregroundStyle(summary.statusColor)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Spacing.sm)
        .glassCard(cornerRadius: Radius.md)
    }
}
