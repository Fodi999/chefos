
//
//  PlanProgressRing.swift
//  ChefOS — Presentation/Plan/Components
//
//  Circular progress ring with icon + numeric label.
//  Extracted from PlanView.swift (DDD refactor).
//

import SwiftUI

// MARK: - PlanProgressRing

struct PlanProgressRing: View {
    let progress: Double
    let icon: String
    let current: Int
    let target: Int
    let unit: String
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.12), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
                Image(systemName: icon)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(color)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 3) {
                    Text(current >= 1000
                         ? String(format: "%,d", current).replacingOccurrences(of: ",", with: " ")
                         : "\(current)")
                        .appStyle(.headline)
                    Text("/ \(target >= 1000 ? String(format: "%,d", target).replacingOccurrences(of: ",", with: " ") : "\(target)")")
                        .appStyle(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
                Text(unit)
                    .appStyle(.caption2)
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
    }
}
