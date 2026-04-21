//
//  Typography.swift
//  ChefOS — DesignSystem
//
//  All text styles in one place.
//  Usage: Text("Hello").appStyle(.title)
//

import SwiftUI

// MARK: - Text Style Enum

enum AppTextStyle {
    case largeTitle    // 34pt bold
    case title         // 24pt semibold
    case title2        // 20pt semibold
    case headline      // 17pt semibold
    case body          // 16pt regular
    case bodyMedium    // 16pt medium
    case subheadline   // 14pt regular
    case caption       // 13pt regular
    case caption2      // 12pt regular
    case micro         // 11pt regular

    // ── Product-level roles ────────────────────────────────────
    /// Заголовок секции в списке (15pt semibold)
    case section       // 15pt semibold
    /// Заголовок секции — синоним `section`, читается в контексте View
    case sectionTitle  // 15pt semibold
    /// Крупный числовой показатель на dashboard (28pt bold)
    case metric        // 28pt bold
    /// Значение нутриента в строке (13pt bold)
    case nutrientValue // 13pt bold
    /// Метка пилюли / тега (12pt medium)
    case tag           // 12pt medium
    /// Метка кнопки (15pt semibold)
    case button        // 15pt semibold
}

extension Text {
    func appStyle(_ style: AppTextStyle) -> some View {
        self.font(Typography.font(for: style))
    }
}

extension View {
    /// Applies an `AppTextStyle` font to any View (labels, buttons, etc.)
    func appStyle(_ style: AppTextStyle) -> some View {
        self.font(Typography.font(for: style))
    }
}

enum Typography {
    static func font(for style: AppTextStyle) -> Font {
        switch style {
        case .largeTitle:   return .system(size: 34, weight: .bold,     design: .default)
        case .title:        return .system(size: 24, weight: .semibold,  design: .default)
        case .title2:       return .system(size: 20, weight: .semibold,  design: .default)
        case .headline:     return .system(size: 17, weight: .semibold,  design: .default)
        case .body:         return .system(size: 16, weight: .regular,   design: .default)
        case .bodyMedium:   return .system(size: 16, weight: .medium,    design: .default)
        case .subheadline:  return .system(size: 14, weight: .regular,   design: .default)
        case .caption:      return .system(size: 13, weight: .regular,   design: .default)
        case .caption2:     return .system(size: 12, weight: .regular,   design: .default)
        case .micro:        return .system(size: 11, weight: .regular,   design: .default)
        case .section:      return .system(size: 15, weight: .semibold,  design: .default)
        case .sectionTitle: return .system(size: 15, weight: .semibold,  design: .default)
        case .metric:       return .system(size: 28, weight: .bold,      design: .default)
        case .nutrientValue:return .system(size: 13, weight: .bold,      design: .default)
        case .tag:          return .system(size: 12, weight: .medium,    design: .default)
        case .button:       return .system(size: 15, weight: .semibold,  design: .default)
        }
    }
}

// MARK: - Legacy ViewModifier aliases (keeps old code compiling)

struct HeaderTextStyle: ViewModifier {
    func body(content: Content) -> some View {
        content.font(Typography.font(for: .title2)).tracking(-0.2)
    }
}

struct CaptionTextStyle: ViewModifier {
    func body(content: Content) -> some View {
        content.font(Typography.font(for: .caption)).opacity(0.7)
    }
}

extension View {
    func premiumHeader() -> some View { modifier(HeaderTextStyle()) }
    func premiumCaption() -> some View { modifier(CaptionTextStyle()) }
}
