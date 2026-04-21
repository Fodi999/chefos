
//
//  StatRing.swift
//  ChefOS — DesignSystem
//
//  Apple Health–style circular progress ring.
//  Simple, readable, data-first — no glow, no gradient.
//
//  Usage:
//    StatRing(value: 1840, target: 2200, unit: "kcal",
//             label: "Calories", accent: .orange)
//

import SwiftUI

// MARK: - StatRing

/// Apple Health–style ring.
/// `lineWidth` controls visual hierarchy: make the primary ring thicker (e.g. 10),
/// secondary rings thinner (e.g. 6) so the eye reads importance at a glance.
struct StatRing: View {
    let value: Int
    let target: Int
    let unit: String
    let label: String
    var accent: Color = AppColors.primary
    var size: CGFloat = 80
    /// Visual weight — larger = more prominent. Use 10 for primary, 6 for secondary.
    var lineWidth: CGFloat = 8

    private var progress: Double {
        guard target > 0 else { return 0 }
        return min(Double(value) / Double(target), 1.0)
    }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                // Track (muted)
                Circle()
                    .stroke(accent.opacity(0.10), lineWidth: lineWidth)

                // Gradient fill arc
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        AngularGradient(
                            colors: [accent.opacity(0.6), accent],
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(-90 + 360 * progress)
                        ),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: progress)

                // Center value
                VStack(spacing: 1) {
                    Text(compactValue)
                        .font(.system(size: size * 0.22, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)
                    Text(unit)
                        .font(.system(size: size * 0.13, weight: .regular))
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
            .frame(width: size, height: size)

            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppColors.textSecondary)
                .lineLimit(1)
        }
    }

    private var compactValue: String {
        value >= 1000 ? "\(value / 1000).\((value % 1000) / 100)k" : "\(value)"
    }
}

// MARK: - StatRingRow (3 rings side by side, as in Health Summary)

struct StatRingRow: View {
    struct Stat {
        let value: Int
        let target: Int
        let unit: String
        let label: String
        let accent: Color
        /// Visual weight. Primary metric = 10, secondary = 6.
        var lineWidth: CGFloat = 8
    }

    let stats: [Stat]
    var ringSize: CGFloat = 76

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(stats.enumerated()), id: \.offset) { _, stat in
                StatRing(
                    value: stat.value,
                    target: stat.target,
                    unit: stat.unit,
                    label: stat.label,
                    accent: stat.accent,
                    size: ringSize,
                    lineWidth: stat.lineWidth
                )
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, Spacing.sm)
        .padding(.horizontal, Spacing.xs)
    }
}
