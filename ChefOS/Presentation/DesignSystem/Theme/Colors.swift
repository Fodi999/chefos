//
//  Colors.swift
//  ChefOS — DesignSystem
//
//  Single source of truth for all app colors.
//  Optimized for Real Product (Apple HIG) - Zero visual noise.
//

import SwiftUI

// MARK: - App Color Palette (System-Standardized)

enum AppColors {
    // ── 90% Dark base (HIG Grouped Style) ──────────────────────
    
    /// Main screen background (deep black in dark mode)
    static var background: Color {
        Color(uiColor: .systemGroupedBackground) 
    }

    /// Primary card background (secondary grouped surface)
    static var surface: Color {
        Color(uiColor: .secondarySystemGroupedBackground)
    }

    /// Tertiary raised background (for small nested items)
    static var surfaceRaised: Color {
        Color(uiColor: .tertiarySystemGroupedBackground)
    }

    // ── 8% Primary interactive (No Glow) ────────────────────────
    
    static var primary: Color {
        Color.accentColor
    }

    static var primaryGlow: Color {
        Color.clear // NO noise
    }

    // ── 2% Accent / CTA ─────────────────────────────────────────
    
    static var accent: Color {
        Color.orange
    }

    static var accentGlow: Color {
        Color.clear // NO noise
    }

    // ── Text (System Standard) ──────────────────────────────────
    
    static var textPrimary: Color {
        Color.primary
    }

    static var textSecondary: Color {
        Color.secondary
    }

    static var textTertiary: Color {
        Color.secondary.opacity(0.6)
    }

    // ── Semantic (Solid) ────────────────────────────────────────
    static var success: Color { Color.green }
    static var warning: Color { Color.yellow }
    static var danger:  Color { Color.red }

    // ── System Overlays ─────────────────────────────────────────
    
    static var glassStroke: Color {
        Color(uiColor: .separator).opacity(0.5)
    }

    static var glassFill: Color {
        surface // Real product: avoid overusing material backgrounds for cards
    }

    static var divider: Color {
        Color(uiColor: .separator)
    }

    // ── Bubble (chat) ───────────────────────────────────────────
    static var bubbleUser: Color { primary }
    static var bubbleAI: Color {
        Color(uiColor: .secondarySystemBackground)
    }

    // ── Legacy aliases (Cleaned) ────────────────────────────────
    static var bgPrimary: Color { background }
    static var bgSecondary: Color { surface }
    static var bgTertiary: Color { surfaceRaised }
    static var auroraBlue: Color { primary }
    static var amberGlow: Color { accent }
    static var glowOrange: Color { Color.clear }
    static var glowBlue: Color { Color.clear }
    static var obsidianBase: Color { background }
    static var obsidianPanel: Color { surface }
}

// MARK: - Legacy Color Extensions

extension Color {
    static let obsidianBase   = AppColors.background
    static let obsidianPanel  = AppColors.surface
    static let bgTertiary     = AppColors.surfaceRaised
    static let auroraBlue     = AppColors.primary
    static let amberGlow      = AppColors.accent
    static let glowOrange     = AppColors.glowOrange
    static let glowBlue       = AppColors.glowBlue
    static let bgPrimary      = AppColors.background
    static let bgSecondary    = AppColors.surface
    static let bubbleUser     = AppColors.bubbleUser
    static let bubbleAI       = AppColors.bubbleAI
}
