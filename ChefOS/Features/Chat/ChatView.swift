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
                AppColors.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Usage indicator
                    HStack(spacing: .spacingS) {
                        Image(systemName: "sparkles")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(AppColors.primary)
                        Text("\(l10n.t("chat.actionsLeft")) \(usageService.chatsRemaining)")
                            .appStyle(.caption)
                        Spacer()
                        if usageService.purchasedActions > 0 {
                            Text("+\(usageService.purchasedActions) \(l10n.t("chat.purchased"))")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(AppColors.primary)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(AppColors.surface)

                    // Soft warning / cost preview banner
                    if !usageService.actionCostPreview.isEmpty {
                        HStack(spacing: .spacingS) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption2)
                                .foregroundStyle(AppColors.accent)
                            Text(usageService.actionCostPreview)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppColors.accent)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppColors.accent.opacity(0.1))
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
            .toolbarBackground(AppColors.surface, for: .navigationBar)
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
        EmptyView()
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
// Routes each message to the correct visual representation.

struct MessageBubble: View {
    let message: Message

    var body: some View {
        // Structured AI cards — full width, no bubble indentation
        switch message.cardType {
        case .greeting(let name):
            GreetingCard(name: name)
                .padding(.horizontal)
        case .goal(let goal, let focus):
            GoalCard(goal: goal, focus: focus)
                .padding(.horizontal)
        case .dailyTargets(let kcal, let protein):
            DailyTargetsCard(kcal: kcal, protein: protein)
                .padding(.horizontal)
        case .restrictions(let items):
            RestrictionsCard(items: items)
                .padding(.horizontal)
        case .none:
            // Standard bubble (user message or plain AI reply)
            plainBubble
        }
    }

    private var plainBubble: some View {
        HStack(alignment: .top) {
            if message.isFromUser { Spacer(minLength: 60) }

            Group {
                switch message.content {
                case .text(let text):
                    Text(text)
                        .appStyle(.body)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, 11)
                        .foregroundStyle(message.isFromUser ? .white : AppColors.textPrimary)
                        .background(
                            message.isFromUser
                                ? AnyShapeStyle(AppColors.primary)
                                : AnyShapeStyle(AppColors.surface),
                            in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        )
                case .recipeCard(let recipe):
                    RecipeCardBubble(recipe: recipe)
                case .image(let uiImage):
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: 220, maxHeight: 260)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
            }

            if !message.isFromUser { Spacer(minLength: 60) }
        }
        .padding(.horizontal)
    }
}

// MARK: - ChatCard (base container)

private struct ChatCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
    }
}

// MARK: - GreetingCard

struct GreetingCard: View {
    let name: String

    var body: some View {
        ChatCard {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(AppColors.primary)
                    .frame(width: 44, height: 44)
                    .background(AppColors.primary.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(name.isEmpty ? "Hello!" : "Hello, \(name)")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(AppColors.textPrimary)
                    Text("ChefOS · Your personal chef AI")
                        .font(.system(size: 13))
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
            .padding(Spacing.sm)
        }
    }
}

// MARK: - GoalCard

struct GoalCard: View {
    let goal: String
    let focus: String

    var body: some View {
        ChatCard {
            chatCardHeader(icon: "target", label: "Goal", accent: AppColors.accent)
            HealthDivider()
            VStack(alignment: .leading, spacing: 4) {
                Text(goal)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)
                Text(focus)
                    .font(.system(size: 13))
                    .foregroundStyle(AppColors.textSecondary)
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, 12)
        }
    }
}

// MARK: - DailyTargetsCard

struct DailyTargetsCard: View {
    let kcal: Int
    let protein: Int

    var body: some View {
        ChatCard {
            chatCardHeader(icon: "chart.bar.fill", label: "Today's Targets", accent: SemanticColors.nutrient(.calories))
            HealthDivider()
            HStack(spacing: 0) {
                targetCell(value: "\(kcal)", unit: "kcal", label: "Calories",
                           accent: SemanticColors.nutrient(.calories))
                Divider().frame(height: 44)
                targetCell(value: "\(protein)", unit: "g", label: "Protein",
                           accent: SemanticColors.nutrient(.protein))
            }
            .padding(.vertical, 4)
        }
    }

    private func targetCell(value: String, unit: String, label: String, accent: Color) -> some View {
        VStack(spacing: 3) {
            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(accent)
                Text(unit)
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.textSecondary)
            }
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
}

// MARK: - RestrictionsCard

struct RestrictionsCard: View {
    let items: [String]

    var body: some View {
        ChatCard {
            chatCardHeader(icon: "exclamationmark.shield.fill", label: "Restrictions", accent: AppColors.warning)
            HealthDivider()
            FlowLayout(spacing: 6) {
                ForEach(items, id: \.self) { item in
                    Text(item)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppColors.warning)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(AppColors.warning.opacity(0.1), in: Capsule())
                }
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, 12)
        }
    }
}

// MARK: - Card section header helper

@ViewBuilder
private func chatCardHeader(icon: String, label: String, accent: Color) -> some View {
    HStack(spacing: 8) {
        Image(systemName: icon)
            .font(.caption.weight(.semibold))
            .foregroundStyle(accent)
        Text(label.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(AppColors.textSecondary)
            .tracking(0.5)
    }
    .padding(.horizontal, Spacing.sm)
    .padding(.top, 12)
    .padding(.bottom, 6)
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
                    .foregroundStyle(AppColors.accent)
            }

            HealthDivider()

            HStack {
                Label("\(recipe.calories) kcal", systemImage: "flame.fill")
                    .font(.subheadline)
                    .foregroundStyle(SemanticColors.nutrient(.calories))
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
        .padding(Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
    }
}

// MARK: - ThinkingIndicator

struct ThinkingIndicator: View {
    @State private var phase: Int = 0
    @EnvironmentObject var l10n: LocalizationService
    private let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(AppColors.primary)
                        .frame(width: 7, height: 7)
                        .scaleEffect(phase == index ? 1.35 : 0.7)
                        .opacity(phase == index ? 1 : 0.3)
                        .animation(.easeInOut(duration: 0.25), value: phase)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(AppColors.surface, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))

            Text(l10n.t("chat.thinking"))
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(.horizontal)
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

