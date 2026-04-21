// MARK: - Presentation/Recipes/Stock/ExpiryProgressBar.swift
// Extracted from RecipesView.swift as part of DDD refactoring

import SwiftUI

struct ExpiryProgressBar: View {
    let days: Int
    let maxDays: Int
    @State private var animated = false

    private var progress: Double {
        let total = max(Double(maxDays), 1)
        let remaining = max(Double(days), 0)
        return min(remaining / total, 1.0)
    }

    private var barColor: Color {
        if days <= 1 { return .red }
        if days <= 3 { return .orange }
        if days <= 7 { return .yellow }
        return .green
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.08))
                Capsule()
                    .fill(barColor.gradient)
                    .frame(width: geo.size.width * (animated ? progress : 0))
            }
        }
        .clipShape(Capsule())
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.1)) {
                animated = true
            }
        }
    }
}
