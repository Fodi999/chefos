//
//  ProgressRing.swift
//  ChefOS — DesignSystem
//
//  Circular progress ring for calories, macros, budget.
//  Usage: ProgressRing(progress: 0.72, color: AppColors.primary, size: 60)
//

import SwiftUI

struct RingProgress: View {
    let progress: Double        // 0.0 … 1.0
    var color: Color = AppColors.primary
    var trackColor: Color = AppColors.surface
    var lineWidth: CGFloat = 6
    var size: CGFloat = 56
    var label: String? = nil

    var body: some View {
        ZStack {
            // Track
            Circle()
                .stroke(trackColor, lineWidth: lineWidth)

            // Fill
            Circle()
                .trim(from: 0, to: min(progress, 1))
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.premiumSpring, value: progress)

            // Centre label
            if let label {
                Text(label)
                    .font(Typography.font(for: .micro))
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary)
            }
        }
        .frame(width: size, height: size)
    }
}
