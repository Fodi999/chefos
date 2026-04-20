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
            VStack(alignment: .leading, spacing: 12) {
                // Clean text field — no extra styling, just text
                TextField(l10n.t("chat.placeholder"), text: $text, axis: .vertical)
                    .lineLimit(1...5)
                    .foregroundStyle(.white)
                    .font(.body)
                    .tint(.orange)
                    .focused($isFocused)
                    .submitLabel(.send)
                    .onSubmit { sendAndDismiss() }

                // Subtle tool hints
                HStack(spacing: 6) {
                    ComposerToolButton(icon: "sparkles", label: l10n.t("chat.ai"), color: .purple) {
                        onAISuggest()
                    }
                    ComposerToolButton(icon: "camera.fill", label: l10n.t("chat.photo"), color: .orange) {
                        onCamera()
                    }
                    ComposerToolButton(icon: "waveform", label: l10n.t("chat.voice"), color: .cyan) {
                        // stub
                    }
                    Spacer()
                }
            }
            .padding(16)
            .padding(.trailing, 50)

            // Send — alive when ready, ghost when not
            Button(action: sendAndDismiss) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(
                        canSend
                            ? AnyShapeStyle(LinearGradient(
                                colors: [.orange, .pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                              ))
                            : AnyShapeStyle(Color.white.opacity(0.06))
                    )
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(canSend ? 0.3 : 0.06), lineWidth: 0.5)
                    )
                    .shadow(color: canSend ? .orange.opacity(0.7) : .clear, radius: 14, y: 2)
            }
            .buttonStyle(PressButtonStyle())
            .disabled(!canSend)
            .opacity(canSend ? 1 : 0.4)
            .animation(.easeOut(duration: 0.2), value: canSend)
            .padding(12)
        }
        // Light airy glass — not heavy block
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.18), Color.white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
        .shadow(color: .black.opacity(0.3), radius: 20, y: 8)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
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
