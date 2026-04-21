//
//  BackgroundModifier.swift
//  ChefOS — DesignSystem
//
//  Global background modifier — use on root views.
//  Usage: .appBackground()
//

import SwiftUI

struct AppBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        ZStack {
            AppColors.background.ignoresSafeArea()
            content
        }
    }
}

extension View {
    func appBackground() -> some View {
        modifier(AppBackgroundModifier())
    }
}

// MARK: - Gradient Background (legacy compat)

extension LinearGradient {
    static let userBubble = LinearGradient(
        colors: [AppColors.primary, Color(red: 0.1, green: 0.4, blue: 0.8)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let screenBackground = LinearGradient(
        colors: [AppColors.background, Color(red: 0.03, green: 0.03, blue: 0.04)],
        startPoint: .top,
        endPoint: .bottom
    )

    static let cardGlass = LinearGradient(
        colors: [Color.white.opacity(0.12), Color.white.opacity(0.04)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
