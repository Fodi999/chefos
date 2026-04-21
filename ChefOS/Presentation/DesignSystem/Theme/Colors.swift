//
//  Colors.swift
//  ChefOS — DesignSystem
//
//  Single source of truth for all app colors.
//  Usage: AppColors.background, AppColors.primary, etc.
//

import SwiftUI

// MARK: - App Color Palette (90 / 8 / 2 Rule)

enum AppColors {
    // ── 90% Dark base ──────────────────────────────────────────
    static let background   = Color(red: 0.04, green: 0.04, blue: 0.05) // #0A0A0D
    static let surface      = Color(red: 0.06, green: 0.06, blue: 0.08) // #0F0F14
    static let surfaceRaised = Color(red: 0.08, green: 0.08, blue: 0.10) // #141418

    // ── 8% Primary interactive (aurora blue) ───────────────────
    static let primary      = Color(red: 0.10, green: 0.60, blue: 0.95) // #1A99F2
    static let primaryGlow  = Color(red: 0.10, green: 0.60, blue: 0.95).opacity(0.20)

    // ── 2% Accent / CTA (amber) ────────────────────────────────
    static let accent       = Color(red: 0.95, green: 0.50, blue: 0.10) // #F28019
    static let accentGlow   = Color(red: 0.95, green: 0.50, blue: 0.10).opacity(0.40)

    // ── Text ───────────────────────────────────────────────────
    static let textPrimary   = Color.white
    static let textSecondary = Color.white.opacity(0.60)
    static let textTertiary  = Color.white.opacity(0.35)

    // ── Semantic ───────────────────────────────────────────────
    static let success  = Color(red: 0.20, green: 0.80, blue: 0.40)
    static let warning  = Color(red: 0.95, green: 0.70, blue: 0.10)
    static let danger   = Color(red: 0.95, green: 0.30, blue: 0.30)

    // ── Glass / overlays ───────────────────────────────────────
    static let glassStroke = Color.white.opacity(0.05)
    static let glassFill   = Color.white.opacity(0.04)
    static let divider     = Color.white.opacity(0.08)

    // ── Bubble (chat) ──────────────────────────────────────────
    static let bubbleUser = primary
    static let bubbleAI   = Color.white.opacity(0.06)

    // ── Legacy aliases (for backward compat) ───────────────────
    static let bgPrimary   = background
    static let bgSecondary = surface
    static let bgTertiary  = surfaceRaised
    static let auroraBlue  = primary
    static let amberGlow   = accent
    static let glowOrange  = accentGlow
    static let glowBlue    = primaryGlow
    static let obsidianBase  = background
    static let obsidianPanel = surface
}

// MARK: - Legacy Color Extensions (keeps old call sites compiling)

extension Color {
    static let obsidianBase   = AppColors.background
    static let obsidianPanel  = AppColors.surface
    static let bgTertiary     = AppColors.surfaceRaised
    static let auroraBlue     = AppColors.primary
    static let amberGlow      = AppColors.accent
    static let glowOrange     = AppColors.accentGlow
    static let glowBlue       = AppColors.primaryGlow
    static let bgPrimary      = AppColors.background
    static let bgSecondary    = AppColors.surface
    static let bubbleUser     = AppColors.bubbleUser
    static let bubbleAI       = AppColors.bubbleAI
}
