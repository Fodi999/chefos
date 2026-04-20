//
//  Theme.swift
//  ChefOS
//

import SwiftUI

// MARK: - Spacing System (2026 standard)

extension CGFloat {
    static let spacingXS: CGFloat = 4
    static let spacingS:  CGFloat = 8
    static let spacingM:  CGFloat = 16
    static let spacingL:  CGFloat = 24
    static let spacingXL: CGFloat = 32
}

// MARK: - Color Palette (The 90/8/2 Rule)

extension Color {
    // 90% - Dark Base
    static let obsidianBase = Color(red: 0.04, green: 0.04, blue: 0.05)
    static let obsidianPanel = Color(red: 0.06, green: 0.06, blue: 0.08)
    
    // 8% - Primary Interactive
    static let auroraBlue = Color(red: 0.1, green: 0.6, blue: 0.95)
    
    // 2% - Secondary Attention / CTA
    static let amberGlow = Color(red: 0.95, green: 0.5, blue: 0.1)
    
    // Legacy support (to avoid massive initial breakage, map to new equivalents where possible)
    static let bgPrimary = obsidianBase
    static let bgSecondary = obsidianPanel
    static let bgTertiary = Color(red: 0.08, green: 0.08, blue: 0.1)
    static let bubbleUser = auroraBlue
    static let bubbleAI = Color.white.opacity(0.06)
    static let accent = auroraBlue
    static let glowOrange = amberGlow.opacity(0.4)
    static let glowBlue = auroraBlue.opacity(0.2)
}

// MARK: - Typography (Premium Tool)

struct HeaderTextStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 20, weight: .semibold, design: .default))
            .tracking(-0.2)
    }
}

struct CaptionTextStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 13, weight: .regular, design: .default))
            .opacity(0.7)
    }
}

extension View {
    func premiumHeader() -> some View {
        modifier(HeaderTextStyle())
    }
    
    func premiumCaption() -> some View {
        modifier(CaptionTextStyle())
    }
}

// MARK: - Gradients

extension LinearGradient {
    static let userBubble = LinearGradient(
        colors: [Color.auroraBlue, Color(red: 0.1, green: 0.4, blue: 0.8)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let screenBackground = LinearGradient(
        colors: [
            Color.obsidianBase,
            Color(red: 0.03, green: 0.03, blue: 0.04)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    static let cardGlass = LinearGradient( // Not used in new glass, but kept for legacy
        colors: [
            Color.white.opacity(0.12),
            Color.white.opacity(0.04)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Glass Card Modifier (2026 style)

struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat = 20

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial.opacity(0.6))
                    .blur(radius: 10)
            }
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 20) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius))
    }
}

// MARK: - Ambient Glow Modifier

struct AmbientGlow: ViewModifier {
    var color: Color = .glowBlue
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
    func ambientGlow(color: Color = .glowBlue, radius: CGFloat = 30) -> some View {
        modifier(AmbientGlow(color: color, radius: radius))
    }
}

// MARK: - Animation Standards

extension Animation {
    /// The "Controlled Fluid" animation standard for 2026
    static var premiumSpring: Animation {
        .spring(response: 0.4, dampingFraction: 0.8)
    }
}

// MARK: - Press Buton Style

struct PressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(.premiumSpring, value: configuration.isPressed)
    }
}
