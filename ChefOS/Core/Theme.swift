//
//  Theme.swift
//  ChefOS
//

import SwiftUI

// MARK: - Color Palette

extension Color {
    static let bgPrimary = Color(.systemBackground)
    static let bgSecondary = Color(.secondarySystemBackground)
    static let bgTertiary = Color(.tertiarySystemBackground)
    static let bubbleUser = Color.orange
    static let bubbleAI = Color.white.opacity(0.08)
    static let accent = Color.orange
    static let glowOrange = Color.orange.opacity(0.45)
    static let glowBlue = Color.cyan.opacity(0.25)
}

// MARK: - Gradients

extension LinearGradient {
    static let userBubble = LinearGradient(
        colors: [.orange, .pink],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let screenBackground = LinearGradient(
        colors: [
            Color(red: 0.04, green: 0.04, blue: 0.08),
            Color(red: 0.06, green: 0.08, blue: 0.18),
            Color(red: 0.03, green: 0.03, blue: 0.06)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    static let cardGlass = LinearGradient(
        colors: [
            Color.white.opacity(0.12),
            Color.white.opacity(0.04)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Glass Card Modifier

struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat = 20

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    // Layer 1: material blur
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.regularMaterial)

                    // Layer 2: inner light gradient
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.1),
                                    Color.white.opacity(0.02)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            }
            // Layer 3: edge highlight
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.2),
                                Color.white.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            )
            // Layer 4: depth shadow
            .shadow(color: .black.opacity(0.35), radius: 16, y: 8)
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 20) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius))
    }
}

// MARK: - Ambient Glow Modifier

struct AmbientGlow: ViewModifier {
    var color: Color = .glowOrange
    var radius: CGFloat = 30

    func body(content: Content) -> some View {
        content
            .background(
                color
                    .blur(radius: radius)
                    .opacity(0.5)
            )
    }
}

extension View {
    func ambientGlow(color: Color = .glowOrange, radius: CGFloat = 30) -> some View {
        modifier(AmbientGlow(color: color, radius: radius))
    }
}
