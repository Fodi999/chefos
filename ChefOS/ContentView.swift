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
        HStack(spacing: .spacingM) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.auroraBlue.opacity(0.15))
                    .frame(width: 40, height: 40)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.auroraBlue.opacity(0.3), lineWidth: 1)
                    )

                Image(systemName: "sparkles")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color.auroraBlue)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("ChefOS")
                    .premiumHeader()
                    .foregroundStyle(.white)
                Text("Intelligence Engine")
                    .premiumCaption()
                    .textCase(.uppercase)
            }

            Spacer()

            Button(action: {}) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .buttonStyle(PressButtonStyle())
        }
        .padding(.horizontal, .spacingL)
        .padding(.vertical, .spacingM)
        .background {
            Rectangle()
                .fill(.ultraThinMaterial.opacity(0.6))
                .blur(radius: 5)
                .mask(LinearGradient(colors: [.black, .black.opacity(0.8), .clear], startPoint: .top, endPoint: .bottom))
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
        ZStack {
            Color.obsidianBase
                .ignoresSafeArea()

            // Subtle ambient glows (8% Primary, 2% Secondary)
            ZStack {
                Circle()
                    .fill(Color.auroraBlue.opacity(0.08))
                    .frame(width: 400, height: 400)
                    .offset(x: animate ? 100 : -100, y: animate ? -50 : 50)
                    .blur(radius: 120)

                Circle()
                    .fill(Color.amberGlow.opacity(0.04)) // Very restricted warm accent
                    .frame(width: 350, height: 350)
                    .offset(x: animate ? -120 : 120, y: animate ? 80 : -80)
                    .blur(radius: 120)
            }
            .animation(.easeInOut(duration: 12).repeatForever(autoreverses: true), value: animate)
            .onAppear { animate = true }
        }
    }
}

private struct GlassComposer: View {
    @Binding var text: String
    @FocusState private var isFocused: Bool

    let canSend: Bool
    let onSend: () -> Void

    var body: some View {
        VStack(spacing: .spacingS) {
            // Header Row
            HStack(spacing: .spacingXS) {
                Text("245")
                    .premiumHeader()
                Text("Project Requests")
                    .premiumCaption()
                
                Spacer()
                
                Text("PRO")
                    .font(.system(size: 10, weight: .black, design: .default))
                    .foregroundStyle(Color.amberGlow)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.amberGlow.opacity(0.1), in: Capsule())
            }
            .padding(.horizontal, .spacingS)
            .foregroundStyle(.white)

            // Input Container
            VStack(alignment: .leading, spacing: 0) {
                TextField("Start with anything...", text: $text, axis: .vertical)
                    .textFieldStyle(.plain)
                    .focused($isFocused)
                    .lineLimit(1...5)
                    .padding(.horizontal, .spacingM)
                    .padding(.vertical, 14)
                    .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(isFocused ? 0.2 : 0.05), lineWidth: 1)
                    )
                    .foregroundStyle(.white)
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
                        .foregroundStyle(canSend ? Color.obsidianBase : .white.opacity(0.5))
                        .frame(width: 36, height: 36)
                        .background {
                            Circle()
                                .fill(canSend ? Color.auroraBlue : Color.white.opacity(0.1))
                        }
                        .scaleEffect(isFocused ? 1.05 : 1.0)
                }
                .buttonStyle(PressButtonStyle())
                .disabled(!canSend)
                .animation(.premiumSpring, value: canSend)
            }
            .padding(.top, .spacingXS)
            .padding(.horizontal, .spacingXS)
        }
        .padding(.spacingM)
        .glassCard(cornerRadius: 24)
        .padding(.horizontal, .spacingS)
        .padding(.bottom, .spacingM)
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

            VStack(alignment: isUser ? .trailing : .leading, spacing: .spacingXS) {
                Text(message.text)
                    .font(.system(size: 15, weight: .regular, design: .default))
                    .foregroundStyle(isUser ? .white : .white.opacity(0.9))
                    .padding(.horizontal, .spacingM)
                    .padding(.vertical, 12)
                    .background {
                        if isUser {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(Color.auroraBlue)
                                // Only auroraBlue, no gradients, less cheap
                                .shadow(color: Color.auroraBlue.opacity(0.25), radius: 10, x: 0, y: 5)
                        } else {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(Color.obsidianPanel.opacity(0.6))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
                                )
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
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.white.opacity(0.08))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .onAppear {
            dotScale = 1.0
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    ContentView()
}
