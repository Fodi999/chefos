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


// Deprecated legacy gradients. Use AppColors tokens directly.
