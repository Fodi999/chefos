//
//  ContentView.swift
//  ChefOS
//
//  Created by Дмитрий Фомин on 18/04/2026.
//

import SwiftUI

struct ContentView: View {
    @State private var messages: [ChatMessage] = [
        ChatMessage(text: "Hi, I am your ChefOS assistant. What are we cooking today?", sender: .assistant),
        ChatMessage(text: "I have tomatoes, basil, pasta, and parmesan.", sender: .user),
        ChatMessage(text: "That is perfect for a quick tomato basil pasta. I can help with timing, substitutions, or a full recipe.", sender: .assistant)
    ]
    @State private var draftMessage = ""
    @State private var isThinking = false

    var body: some View {
        ZStack {
            DeepObsidianBackground()

            VStack(spacing: 0) {
                header

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(messages) { message in
                                ContentMessageBubble(message: message)
                                    .id(message.id)
                            }
                            
                            if isThinking {
                                ThinkingBubble()
                                    .id("thinking")
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 20)
                        .padding(.bottom, 120)
                    }
                    .scrollIndicators(.hidden)
                    .onChange(of: messages.count) { _, _ in
                        scrollToBottom(with: proxy)
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            GlassComposer(text: $draftMessage, canSend: canSend, onSend: sendMessage)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 10)
        }
        .animation(.snappy, value: messages.count)
    }

    private var header: some View {
        HStack(spacing: Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                    .fill(AppColors.primary.opacity(0.15))
                    .frame(width: 40, height: 40)
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                            .stroke(AppColors.primary.opacity(0.3), lineWidth: 1)
                    )

                Image(systemName: "sparkles")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(AppColors.primary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("ChefOS")
                    .appStyle(.title2)
                    .foregroundStyle(AppColors.textPrimary)
                Text("Intelligence Engine")
                    .appStyle(.caption)
                    .textCase(.uppercase)
                    .foregroundStyle(AppColors.textSecondary)
            }

            Spacer()

            Button(action: {}) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(AppColors.textSecondary)
            }
            .buttonStyle(PressButtonStyle())
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .background {
            AppColors.surface
                .ignoresSafeArea()
        }
    }

    private var canSend: Bool {
        !draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func sendMessage() {
        let trimmedMessage = draftMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty else { return }

        messages.append(ChatMessage(text: trimmedMessage, sender: .user))
        draftMessage = ""
        isThinking = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.snappy) {
                isThinking = false
                messages.append(ChatMessage(text: "I can help turn that into a clear next step. Tell me your goal, ingredients, or time limit.", sender: .assistant))
            }
        }
    }

    private func scrollToBottom(with proxy: ScrollViewProxy) {
        guard let lastMessage = messages.last else { return }

        withAnimation(.snappy) {
            proxy.scrollTo(lastMessage.id, anchor: .bottom)
        }
    }
}

private struct DeepObsidianBackground: View {
    @State private var animate = false

    var body: some View {
        AppColors.background
            .ignoresSafeArea()
    }
}

private struct GlassComposer: View {
    @Binding var text: String
    @FocusState private var isFocused: Bool

    let canSend: Bool
    let onSend: () -> Void

    var body: some View {
        VStack(spacing: Spacing.sm) {
            // Header Row
            HStack(spacing: Spacing.xs) {
                Text("245")
                    .appStyle(.headline)
                Text("Project Requests")
                    .appStyle(.caption)
                
                Spacer()
                
                Text("PRO")
                    .appStyle(.micro)
                    .bold()
                    .foregroundStyle(AppColors.accent)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(AppColors.accent.opacity(0.1), in: Capsule())
            }
            .padding(.horizontal, Spacing.sm)
            .foregroundStyle(AppColors.textPrimary)

            // Input Container
            VStack(alignment: .leading, spacing: 0) {
                TextField("Start with anything...", text: $text, axis: .vertical)
                    .textFieldStyle(.plain)
                    .focused($isFocused)
                    .lineLimit(1...5)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, 14)
                    .background(AppColors.glassFill, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                            .stroke(AppColors.glassStroke, lineWidth: 1)
                    )
                    .foregroundStyle(AppColors.textPrimary)
            }

            // Bottom Actions Row
            HStack(spacing: .spacingM) {
                HStack(spacing: .spacingM) {
                    ComposerActionButton(systemName: "sparkles")
                    ComposerActionButton(systemName: "photo.on.rectangle.angled")
                    ComposerActionButton(systemName: "waveform")
                }
                
                Spacer()
                
                Button(action: onSend) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(canSend ? AppColors.background : AppColors.textTertiary)
                        .frame(width: 36, height: 36)
                        .background {
                            Circle()
                                .fill(canSend ? AppColors.primary : AppColors.glassFill)
                        }
                        .scaleEffect(isFocused ? 1.05 : 1.0)
                }
                .buttonStyle(PressButtonStyle())
                .disabled(!canSend)
            }
            .padding(.top, Spacing.xs)
            .padding(.horizontal, Spacing.xs)
        }
        .padding(Spacing.md)
        .surface(.card, cornerRadius: Radius.lg)
        .padding(.horizontal, Spacing.sm)
        .padding(.bottom, Spacing.md)
    }
}

private struct ComposerActionButton: View {
    let systemName: String

    var body: some View {
        Button(action: {}) {
            Image(systemName: systemName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
        }
        .buttonStyle(.plain)
    }
}

private struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let sender: Sender

    enum Sender {
        case user
        case assistant
    }
}

private struct ContentMessageBubble: View {
    let message: ChatMessage

    private var isUser: Bool {
        message.sender == .user
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            if isUser { Spacer(minLength: 64) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: Spacing.xs) {
                Text(message.text)
                    .appStyle(.body)
                    .foregroundStyle(isUser ? .white : AppColors.textPrimary)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, 12)
                    .background {
                        if isUser {
                            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                                .fill(AppColors.primary)
                                .shadow(color: AppColors.primary.opacity(0.25), radius: 10, x: 0, y: 5)
                        } else {
                            AppCard(style: .solid, cornerRadius: Radius.md) { EmptyView() }
                                .overlay {
                                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                                        .stroke(AppColors.glassStroke, lineWidth: 1)
                                }
                        }
                    }
            }

            if !isUser { Spacer(minLength: 64) }
        }
        .padding(.vertical, 2)
    }
}

private struct ThinkingBubble: View {
    @State private var dotScale: CGFloat = 0.5

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(.white.opacity(0.5))
                    .frame(width: 6, height: 6)
                    .scaleEffect(dotScale)
                    .animation(
                        .easeInOut(duration: 0.6)
                        .repeatForever()
                        .delay(Double(index) * 0.2),
                        value: dotScale
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(AppColors.surfaceRaised, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onAppear {
            dotScale = 1.0
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    ContentView()
}
