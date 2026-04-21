//
//  Theme.swift
//  ChefOS
//
//  ⛔  DEPRECATED — не используй этот файл в новом коде.
//  Все стили перенесены в Presentation/DesignSystem/
//
//  Colors    → Presentation/DesignSystem/Theme/Colors.swift
//  Spacing   → Presentation/DesignSystem/Theme/Spacing.swift
//  Radius    → Presentation/DesignSystem/Theme/Radius.swift
//  Shadows   → Presentation/DesignSystem/Theme/Shadows.swift
//  Typography → Presentation/DesignSystem/Typography/Typography.swift
//  Modifiers  → Presentation/DesignSystem/Modifiers/
//  Components → Presentation/DesignSystem/Components/
//

import SwiftUI

// All types (AppColors, Spacing, Radius, Shadows, Typography,
// GlassCard, AmbientGlow, PressButtonStyle, premiumHeader,
// premiumCaption, glassCard, ambientGlow, appBackground,
// LinearGradient extensions, CGFloat spacing extensions)
// are now defined in Presentation/DesignSystem/ and are
// automatically available project-wide — no import needed.

// MARK: - Deprecated typealias stub

@available(*, deprecated, renamed: "AppColors",
           message: "Use AppColors / SemanticColors / Spacing / Radius from DesignSystem")
typealias LegacyTheme = AppColors
