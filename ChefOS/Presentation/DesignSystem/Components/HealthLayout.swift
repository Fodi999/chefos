
//
//  SectionHeader.swift
//  ChefOS — DesignSystem
//
//  Apple Health–style section header: uppercase label + optional action button.
//
//  Usage:
//    SectionHeader("Highlights")
//    SectionHeader("Meals", action: ("Edit", { ... }))
//

import SwiftUI

// MARK: - SectionHeader

struct SectionHeader: View {
    let title: String
    var action: (label: String, handler: () -> Void)? = nil

    init(_ title: String, action: (label: String, handler: () -> Void)? = nil) {
        self.title = title
        self.action = action
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title.uppercased())
                .font(.system(size: 13, weight: .semibold, design: .default))
                .foregroundStyle(AppColors.textSecondary)
                .tracking(0.4)

            Spacer()

            if let action {
                Button(action.label, action: action.handler)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(AppColors.primary)
            }
        }
        .padding(.horizontal, Spacing.sm)
    }
}

// MARK: - GroupCard (Apple Health–style grouped container)

/// Wraps content in a single rounded-rect card — the primary layout primitive.
///
/// Usage:
/// ```swift
/// GroupCard {
///     MetricRow(label: "Calories", value: "1840", unit: "kcal", color: .orange)
///     Divider()
///     MetricRow(label: "Protein",  value: "98",   unit: "g",    color: .cyan)
/// }
/// ```
struct GroupCard<Content: View>: View {
    @ViewBuilder let content: Content
    var cornerRadius: CGFloat = Radius.lg

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

// MARK: - MetricRow (single KPI row inside a GroupCard)

/// One metric line: label on left, value+unit on right.
///
/// Usage:
/// ```swift
/// MetricRow(label: "Calories", value: "1840", unit: "kcal", accent: .orange)
/// MetricRow(label: "Protein",  value: "98",   unit: "g",    accent: .cyan,
///           progress: 0.72)
/// ```
struct MetricRow: View {
    let label: String
    let value: String
    let unit: String
    var accent: Color = AppColors.primary
    /// 0…1 — shows a thin progress bar below if non-nil
    var progress: Double? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(accent)
                        .frame(width: 8, height: 8)
                    Text(label)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(AppColors.textPrimary)
                }
                Spacer()
                HStack(alignment: .lastTextBaseline, spacing: 3) {
                    Text(value)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)
                    Text(unit)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, 12)

            if let progress {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(accent.opacity(0.12))
                        Capsule()
                            .fill(accent)
                            .frame(width: geo.size.width * min(CGFloat(progress), 1))
                            .animation(.easeInOut(duration: 0.4), value: progress)
                    }
                }
                .frame(height: 3)
                .padding(.horizontal, Spacing.sm)
                .padding(.bottom, 12)
            }
        }
    }
}

// MARK: - HealthDivider (thin row separator, as in Apple Health lists)

struct HealthDivider: View {
    var body: some View {
        Divider()
            .padding(.leading, Spacing.sm + 8 + 8) // align with text, skip dot
    }
}
