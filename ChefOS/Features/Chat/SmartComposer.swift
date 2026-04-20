//
//  SmartComposer.swift
//  ChefOS
//

import SwiftUI

// MARK: - Smart Composer (Control Hub)

struct SmartComposer: View {
    @Binding var text: String
    var onSend: () -> Void
    var onCamera: () -> Void
    var onAISuggest: () -> Void
    @FocusState private var isFocused: Bool
    @EnvironmentObject var l10n: LocalizationService

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(alignment: .leading, spacing: .spacingM) {
                // Clean text field — no extra styling, just text
                TextField(l10n.t("chat.placeholder"), text: $text, axis: .vertical)
                    .lineLimit(1...5)
                    .foregroundStyle(.white)
                    .font(.body)
                    .tint(Color.auroraBlue)
                    .focused($isFocused)
                    .submitLabel(.send)
                    .onSubmit { sendAndDismiss() }

                // Subtle tool hints
                HStack(spacing: .spacingS) {
                    ComposerToolButton(icon: "sparkles", label: l10n.t("chat.ai"), color: Color.auroraBlue) {
                        onAISuggest()
                    }
                    ComposerToolButton(icon: "camera.fill", label: l10n.t("chat.photo"), color: Color.auroraBlue) {
                    }
                    ComposerToolButton(icon: "waveform", label: l10n.t("chat.voice"), color: Color.auroraBlue) {
                        // stub
                    }
                    Spacer()
                }
            }
            .padding(.spacingM)
            .padding(.trailing, 50)

            // Send — alive when ready, ghost when not
            Button(action: sendAndDismiss) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(canSend ? Color.obsidianBase : .white.opacity(0.5))
                    .frame(width: 38, height: 38)
                    .background(
                        canSend
                            ? AnyShapeStyle(Color.auroraBlue)
                            : AnyShapeStyle(Color.white.opacity(0.06))
                    )
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(canSend ? 0.3 : 0.05), lineWidth: 1)
                    )
                    // The shadow logic relies on the color, so using an explicit clear or color
            }
            .buttonStyle(PressButtonStyle())
            .disabled(!canSend)
            .animation(.premiumSpring, value: canSend)
            .padding(12)
        }
        .glassCard(cornerRadius: 24)
        .padding(.horizontal, .spacingM)
        .padding(.bottom, .spacingS)
    }

    private func sendAndDismiss() {
        guard canSend else { return }
        isFocused = false
        onSend()
    }
}

// MARK: - Composer Tool Button

struct ComposerToolButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                Text(label)
                    .font(.caption2.weight(.medium))
            }
            .foregroundStyle(color.opacity(0.85))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.1), in: Capsule())
        }
        .buttonStyle(PressButtonStyle())
    }
}

#Preview {
    ZStack {
        LinearGradient.screenBackground.ignoresSafeArea()
        VStack {
            Spacer()
            SmartComposer(
                text: .constant(""),
                onSend: {},
                onCamera: {},
                onAISuggest: {}
            )
        }
    }
    .preferredColorScheme(.dark)
}
