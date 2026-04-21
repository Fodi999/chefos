
//
//  CostRing.swift
//  ChefOS — Presentation/Plan/Components
//
//  Budget ring — shows spent vs target with currency.
//  Extracted from PlanView.swift (DDD refactor).
//

import SwiftUI

// MARK: - CostRing

struct CostRing: View {
    let progress: Double
    let current: Double
    let target: Double
    let color: Color
    var currency: String = "$"

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.12), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: min(progress, 1.0))
                    .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
                Image(systemName: "banknote.fill")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(color)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 3) {
                    Text(String(format: "%.0f", current))
                        .appStyle(.headline)
                    Text("/ \(String(format: "%.0f", target))")
                        .appStyle(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
                Text(currency)
                    .appStyle(.caption2)
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
    }
}
