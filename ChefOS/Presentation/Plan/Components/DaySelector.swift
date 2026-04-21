
//
//  DaySelector.swift
//  ChefOS — Presentation/Plan/Components
//
//  Горизонтальный скролл с ячейками дней.
//  Принимает готовый массив DayCellModel — не знаёт ViewModel.
//

import SwiftUI

// MARK: - Day Cell Model (pure data, no ViewModel dependency)

struct DayCellModel: Identifiable {
    let id: Int            // index in week
    let dayLetter: String
    let dayNumber: String
    let isSelected: Bool
    let isToday: Bool
    let hasMeals: Bool
}

// MARK: - DaySelector

struct DaySelector: View {
    let days: [DayCellModel]
    let onSelect: (Int) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(days) { day in
                        CalendarDayCell(
                            dayLetter: day.dayLetter,
                            dayNumber: day.dayNumber,
                            isSelected: day.isSelected,
                            isToday: day.isToday,
                            hasMeals: day.hasMeals
                        )
                        .id(day.id)
                        .onTapGesture { onSelect(day.id) }
                    }
                }
                .padding(.horizontal, 4)
            }
            .padding(.vertical, 4)
            .productCard(cornerRadius: Radius.lg)
            .onAppear {
                if let selected = days.first(where: { $0.isSelected }) {
                    proxy.scrollTo(selected.id, anchor: .center)
                }
            }
        }
    }
}
