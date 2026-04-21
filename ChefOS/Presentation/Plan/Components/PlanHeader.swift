
//
//  PlanHeader.swift
//  ChefOS — Presentation/Plan/Components
//
//  Day / Week / Month segmented switch — iOS 26 style pill picker with
//  SF Symbol icons and inline text labels. Purely presentational.
//

import SwiftUI

// MARK: - PlanHeader

struct PlanHeader: View {
    let mode: PlanMode
    let dayLabel: String
    let weekLabel: String
    let monthLabel: String
    let onSelect: (PlanMode) -> Void

    var body: some View {
        HStack(spacing: 0) {
            segment(.day,   label: dayLabel)
            segment(.week,  label: weekLabel)
            segment(.month, label: monthLabel)
        }
        .padding(3)
        .background(AppColors.surfaceRaised, in: Capsule())
        .overlay(Capsule().stroke(AppColors.glassStroke, lineWidth: 1))
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func segment(_ value: PlanMode, label: String) -> some View {
        let isActive = mode == value
        return Button {
            withAnimation(.snappy(duration: 0.3)) { onSelect(value) }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: value.iconName)
                    .font(.caption.weight(.semibold))
                Text(label)
                    .appStyle(.button)
            }
            .foregroundStyle(isActive ? .white : AppColors.textSecondary.opacity(0.45))
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity)
            .background {
                if isActive {
                    Capsule().fill(SemanticColors.meal(.breakfast))
                }
            }
            .animation(.snappy(duration: 0.3), value: isActive)
        }
        .buttonStyle(PressButtonStyle())
    }
}
