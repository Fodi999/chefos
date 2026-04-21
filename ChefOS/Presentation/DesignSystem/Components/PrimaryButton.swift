//
//  PrimaryButton.swift
//  ChefOS — DesignSystem
//
//  Usage:
//    PrimaryButton("Сохранить") { ... }
//    PrimaryButton("Отмена", style: .secondary) { ... }
//

import SwiftUI

enum PrimaryButtonStyle {
    case primary    // filled orange/amber
    case secondary  // outlined
    case ghost      // text only
    case danger     // red
}

struct PrimaryButton: View {
    let title: String
    let style: PrimaryButtonStyle
    let isLoading: Bool
    let action: () -> Void

    init(
        _ title: String,
        style: PrimaryButtonStyle = .primary,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.style = style
        self.isLoading = isLoading
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                if isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text(title)
                        .font(Typography.font(for: .bodyMedium))
                        .foregroundColor(foregroundColor)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.xs + 2)
            .background(backgroundView)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            .overlay {
                if style == .secondary {
                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        .stroke(AppColors.primary, lineWidth: 1.5)
                }
            }
        }
        .buttonStyle(PressButtonStyle())
        .disabled(isLoading)
    }

    private var foregroundColor: Color {
        switch style {
        case .primary:   return .white
        case .secondary: return AppColors.primary
        case .ghost:     return AppColors.textSecondary
        case .danger:    return .white
        }
    }

    @ViewBuilder
    private var backgroundView: some View {
        switch style {
        case .primary:   AppColors.accent
        case .secondary: Color.clear
        case .ghost:     Color.clear
        case .danger:    AppColors.danger
        }
    }
}
