//
//  ChatView.swift
//  ChefOS
//

import SwiftUI
import Combine
import UIKit

// MARK: - Features/Chat

struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @EnvironmentObject var usageService: UsageService
    @EnvironmentObject var l10n: LocalizationService
    @State private var showCamera = false
    @State private var showPhotoPicker = false
    @State private var pickedImage: UIImage?

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient.screenBackground
                    .ignoresSafeArea()

                ambientOrbs

                VStack(spacing: 0) {
                    // Usage indicator
                    HStack(spacing: .spacingS) {
                        Image(systemName: "sparkles")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Color.auroraBlue)
                        Text("\(l10n.t("chat.actionsLeft")) \(usageService.chatsRemaining)")
                            .premiumCaption()
                        Spacer()
                        if usageService.purchasedActions > 0 {
                            Text("+\(usageService.purchasedActions) \(l10n.t("chat.purchased"))")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(Color.auroraBlue)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)

                    // Soft warning / cost preview banner
                    if !usageService.actionCostPreview.isEmpty {
                        HStack(spacing: .spacingS) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption2)
                                .foregroundStyle(Color.amberGlow)
                            Text(usageService.actionCostPreview)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.amberGlow)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.yellow.opacity(0.1))
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    messageList

                    SmartComposer(
                        text: $viewModel.draft,
                        onSend: {
                            usageService.requestAction("AI chat", canPerform: usageService.canChat()) {
                                usageService.useChat()
                                viewModel.send()
                            }
                        },
                        onCamera: { showPhotoPicker = true },
                        onAISuggest: {
                            usageService.requestAction("AI suggestion", canPerform: usageService.canChat()) {
                                usageService.useChat()
                                viewModel.triggerAISuggestion()
                            }
                        }
                    )
                }
            }
            .navigationTitle(l10n.t("chat.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .sheet(isPresented: $showPhotoPicker) {
                ImagePicker(image: $pickedImage, sourceType: .photoLibrary)
            }
            .sheet(isPresented: $usageService.showPaywall) {
                PaywallView()
            }
            .onChange(of: pickedImage) { _, newImage in
                if let image = newImage {
                    usageService.requestAction("receipt scan", canPerform: usageService.canScanReceipt()) {
                        usageService.useScanReceipt()
                        viewModel.sendImage(image)
                    }
                    pickedImage = nil
                }
            }
        }
    }

    // MARK: Ambient Background Orbs

    private var ambientOrbs: some View {
        GeometryReader { geo in
            ZStack {
                Circle()
                    .fill(Color.auroraBlue.opacity(0.08))
                    .frame(width: 260, height: 260)
                    .blur(radius: 80)
                    .offset(x: -geo.size.width * 0.3, y: -geo.size.height * 0.15)

                Circle()
                    .fill(Color.amberGlow.opacity(0.04))
                    .frame(width: 200, height: 200)
                    .blur(radius: 70)
                    .offset(x: geo.size.width * 0.3, y: geo.size.height * 0.25)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    // MARK: Message List

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 14) {
                    ForEach(viewModel.messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                            .transition(
                                .asymmetric(
                                    insertion: .move(edge: .bottom)
                                        .combined(with: .opacity),
                                    removal: .opacity
                                )
                            )
                    }

                    if viewModel.isThinking {
                        ThinkingIndicator()
                            .padding(.horizontal)
                            .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    }
                }
                .padding(.vertical, 12)
            }
            .scrollIndicators(.hidden)
            .onChange(of: viewModel.messages.count) {
                withAnimation(.snappy) {
                    proxy.scrollTo(viewModel.messages.last?.id, anchor: .bottom)
                }
            }
        }
    }
}

// MARK: - MessageBubble

struct MessageBubble: View {
    let message: Message

    var body: some View {
        HStack {
            if message.isFromUser { Spacer(minLength: 60) }

            Group {
                switch message.content {
                case .text(let text):
                    textBubble(text)
                case .recipeCard(let recipe):
                    RecipeCardBubble(recipe: recipe)
                case .image(let uiImage):
                    imageBubble(uiImage)
                }
            }

            if !message.isFromUser { Spacer(minLength: 60) }
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private func textBubble(_ text: String) -> some View {
        if message.isFromUser {
            Text(text)
                .padding(.horizontal, .spacingM)
                .padding(.vertical, 12)
                .foregroundStyle(.white)
                .background {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.auroraBlue)
                        .shadow(color: Color.auroraBlue.opacity(0.25), radius: 10, x: 0, y: 5)
                }
        } else {
            Text(text)
                .padding(.horizontal, .spacingM)
                .padding(.vertical, 12)
                .foregroundStyle(Color.white.opacity(0.9))
                .background {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.obsidianPanel.opacity(0.6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(Color.white.opacity(0.05), lineWidth: 1)
                        )
                }
        }
    }

    private func imageBubble(_ uiImage: UIImage) -> some View {
        Image(uiImage: uiImage)
            .resizable()
            .scaledToFill()
            .frame(maxWidth: 220, maxHeight: 260)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
            )
            .shadow(color: Color.obsidianBase.opacity(0.3), radius: 20, y: 10)
    }
}

// MARK: - RecipeCardBubble

struct RecipeCardBubble: View {
    let recipe: Recipe
    @EnvironmentObject var l10n: LocalizationService

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(recipe.title)
                    .font(.headline)
                Spacer()
                Image(systemName: "fork.knife.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.orange)
            }

            Divider()
                .overlay(Color.white.opacity(0.1))

            HStack {
                Label("\(recipe.calories) kcal", systemImage: "flame.fill")
                    .font(.subheadline)
                    .foregroundStyle(.orange)
                Spacer()
                Text("\(recipe.ingredients.count) \(l10n.t("chat.ingredients"))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(recipe.ingredients.joined(separator: " · "))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 20)
    }
}

// MARK: - ThinkingIndicator

struct ThinkingIndicator: View {
    @State private var phase: Int = 0
    @EnvironmentObject var l10n: LocalizationService
    private let timer = Timer.publish(every: 0.35, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color.auroraBlue)
                        .frame(width: 8, height: 8)
                        .scaleEffect(phase == index ? 1.4 : 0.7)
                        .opacity(phase == index ? 1 : 0.35)
                        .animation(.premiumSpring, value: phase)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .glassCard(cornerRadius: 16)

            Text(l10n.t("chat.thinking"))
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)

            Spacer()
        }
        .onReceive(timer) { _ in
            phase = (phase + 1) % 3
        }
    }
}



#Preview {
    ChatView()
        .environmentObject(UsageService())
        .environmentObject(LocalizationService())
        .preferredColorScheme(.dark)
}
