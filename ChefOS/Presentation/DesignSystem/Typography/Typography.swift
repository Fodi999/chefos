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
        let design: Font.Design = .default
        
        let size: CGFloat = {
            switch style {
            case .largeTitle:   return 34
            case .title:        return 24
            case .title2:       return 20
            case .headline:     return 17
            case .body:         return 16
            case .bodyMedium:   return 16
            case .subheadline:  return 14
            case .caption:      return 13
            case .caption2:     return 12
            case .micro:        return 11
            case .section:      return 15
            case .sectionTitle: return 15
            case .metric:       return 28
            case .nutrientValue:return 13
            case .tag:          return 12
            case .button:       return 15
            }
        }()
        
        let weight: Font.Weight = {
            switch style {
            case .largeTitle, .metric: return .bold
            case .title, .title2, .headline, .section, .sectionTitle, .button: return .semibold
            case .bodyMedium: return .medium
            case .nutrientValue, .tag: return .bold
            default: return .regular
            }
        }()

        return .system(size: size, weight: weight, design: design)
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
