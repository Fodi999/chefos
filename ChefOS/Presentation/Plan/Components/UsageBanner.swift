//
//  UsageBanner.swift
//  ChefOS — Presentation/Plan/Components
//
//  Restored component for displaying AI action limits.
//

import SwiftUI

struct UsageBanner: View {
    let icon: String
    let text: String
    let remaining: Int
    let total: Int
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(color)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(text)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 8) {
                    ProgressView(value: Double(remaining), total: Double(total))
                        .tint(color)
                        .scaleEffect(x: 1, y: 0.5, anchor: .center)
                    
                    Text("\(remaining) / \(total)")
                        .font(.caption2.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(color)
                }
            }
        }
        .padding(12)
        .productCard(cornerRadius: Radius.md)
        .overlay(
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .stroke(color.opacity(0.1), lineWidth: 1)
        )
    }
}

#Preview {
    UsageBanner(
        icon: "sparkles",
        text: "Daily Plans Remaining",
        remaining: 3,
        total: 5,
        color: .orange
    )
    .padding()
    .background(AppColors.background)
}
