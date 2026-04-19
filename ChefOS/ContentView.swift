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
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                    .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)

                Image(systemName: "sparkles")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .symbolEffect(.variableColor.iterative.dimInactiveLayers.nonReversing)
            }

            VStack(alignment: .leading, spacing: 0) {
                Text("ChefOS")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("Intelligence Engine")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
                    .textCase(.uppercase)
                    .tracking(1.2)
            }

            Spacer()

            Button(action: {}) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .mask(LinearGradient(colors: [.black, .black, .clear], startPoint: .top, endPoint: .bottom))
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
            Color(red: 0.02, green: 0.02, blue: 0.03) // Deep Obsidian
                .ignoresSafeArea()

            // Subtle ambient glows
            ZStack {
                Circle()
                    .fill(Color(red: 0.1, green: 0.3, blue: 0.8).opacity(0.15))
                    .frame(width: 400, height: 400)
                    .offset(x: animate ? 100 : -100, y: animate ? -50 : 50)
                    .blur(radius: 100)

                Circle()
                    .fill(Color(red: 0.6, green: 0.1, blue: 0.4).opacity(0.1))
                    .frame(width: 350, height: 350)
                    .offset(x: animate ? -120 : 120, y: animate ? 80 : -80)
                    .blur(radius: 90)

                Circle()
                    .fill(Color(red: 0.1, green: 0.6, blue: 0.5).opacity(0.12))
                    .frame(width: 300, height: 300)
                    .offset(x: animate ? 50 : -50, y: animate ? 120 : -120)
                    .blur(radius: 110)
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
        VStack(spacing: 12) {
            // Header Row
            HStack {
                HStack(spacing: 4) {
                    Text("245")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                    Text("Project Requests")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.8))
                }
                
                Spacer()
                
                Text("PRO")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .italic()
            }
            .padding(.horizontal, 4)
            .foregroundStyle(.white)

            // Input Container
            VStack(alignment: .leading, spacing: 0) {
                TextField("Start with anything...", text: $text, axis: .vertical)
                    .textFieldStyle(.plain)
                    .focused($isFocused)
                    .lineLimit(1...5)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(.white)
                    }
                    .foregroundStyle(.black)
            }
            .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)

            // Bottom Actions Row
            HStack(spacing: 20) {
                HStack(spacing: 16) {
                    ComposerActionButton(systemName: "sparkles")
                    ComposerActionButton(systemName: "photo.on.rectangle.angled")
                    ComposerActionButton(systemName: "waveform")
                }
                
                Spacer()
                
                Button(action: onSend) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background {
                            Circle()
                                .fill(Color(red: 0.0, green: 0.5, blue: 1.0)) // Precise blue from photo
                        }
                        .shadow(color: Color.blue.opacity(canSend ? 0.3 : 0), radius: 10, x: 0, y: 5)
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
                .opacity(canSend ? 1 : 0.6)
            }
            .padding(.top, 4)
            .padding(.horizontal, 4)
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                }
        }
        .shadow(color: .black.opacity(0.15), radius: 30, x: 0, y: 15)
        .padding(.horizontal, 12)
        .padding(.bottom, 20)
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

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                Text(message.text)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(isUser ? .white : .white.opacity(0.95))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background {
                        if isUser {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [Color(red: 0.1, green: 0.4, blue: 0.9), Color(red: 0.3, green: 0.2, blue: 0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(color: .blue.opacity(0.2), radius: 10, x: 0, y: 5)
                        } else {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(.white.opacity(0.08))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                }
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
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
