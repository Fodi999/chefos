
//
//  ShimmerModifier.swift
//  ChefOS — DesignSystem
//
//  Shimmer loading skeleton effect.
//  Usage: anyView.shimmering()
//

import SwiftUI

// MARK: - Shimmer Modifier

public struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -200
    @State private var isAnimating = false

    public func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [.clear, .white.opacity(0.08), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .offset(x: phase)
                .mask(content)
                .drawingGroup()
            )
            .onAppear {
                guard !isAnimating else { return }
                isAnimating = true
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 400
                }
            }
            .onDisappear {
                isAnimating = false
            }
    }
}

extension View {
    /// Adds a horizontal shimmer sweep — use on loading skeletons.
    func shimmering() -> some View {
        modifier(ShimmerModifier())
    }
}
