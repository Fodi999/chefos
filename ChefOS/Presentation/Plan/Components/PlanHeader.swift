
//
//  PlanHeader.swift
//  ChefOS — Presentation/Plan/Components
//
//  Day/Week toggle — единственный способ переключить режим вида.
//  Принимает только данные для отображения + callback.
//  Не знает ни ViewModel, ни бизнес-логику.
//

import SwiftUI

// MARK: - PlanHeader

struct PlanHeader: View {
    let showingWeek: Bool
    let dayLabel: String
    let weekLabel: String
    let onSelect: (Bool) -> Void   // true = week

    var body: some View {
        HStack(spacing: 0) {
            segmentButton(label: dayLabel,  isActive: !showingWeek, selectsWeek: false)
            segmentButton(label: weekLabel, isActive: showingWeek,  selectsWeek: true)
        }
        .padding(3)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(AppColors.glassStroke, lineWidth: 1))
        .frame(maxWidth: .infinity, alignment: .center)
    }

    // MARK: - Segment button

    private func segmentButton(label: String, isActive: Bool, selectsWeek: Bool) -> some View {
        Button {
            withAnimation(.snappy(duration: 0.35)) {
                onSelect(selectsWeek)
            }
        } label: {
            Text(label)
                .appStyle(.button)
                .foregroundStyle(isActive ? .white : AppColors.textSecondary.opacity(0.4))
                .padding(.horizontal, 24)
                .padding(.vertical, 9)
                .background {
                    if isActive {
                        Capsule()
                            .fill(LinearGradient(
                                colors: [SemanticColors.meal(.breakfast),
                                         Color(red: 0.9, green: 0.4, blue: 0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .shadow(color: SemanticColors.meal(.breakfast).opacity(0.3), radius: 10, y: 3)
                    }
                }
                .animation(.snappy(duration: 0.3), value: isActive)
        }
        .buttonStyle(PressButtonStyle())
    }
}
