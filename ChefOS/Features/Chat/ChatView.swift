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
                        MessageBubble(message: message, onAction: { action in
                            Task { @MainActor in viewModel.handleAction(action) }
                        })
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
    var onAction: ((ChatAction) -> Void)? = nil

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
        case .product(let card):
            ProductBotCard(card: card, onAction: onAction)
                .padding(.horizontal)
        case .nutrition(let card):
            NutritionBotCard(card: card)
                .padding(.horizontal)
        case .conversion(let card):
            ConversionBotCard(card: card)
                .padding(.horizontal)
        case .recipe(let card):
            RecipeBotCard(card: card, onAction: onAction)
                .padding(.horizontal)
        case .cookingLoss(let card):
            CookingLossBotCard(card: card)
                .padding(.horizontal)
        case .confirmation(let icon, let title, let subtitle, let tint):
            ConfirmationCard(icon: icon, title: title, subtitle: subtitle, tint: tint)
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

// MARK: - ProductBotCard

struct ProductBotCard: View {
    let card: APIClient.BackendProductCard
    var onAction: ((ChatAction) -> Void)? = nil
    @EnvironmentObject var l10n: LocalizationService
    @State private var showingDetail = false

    var body: some View {
        ChatCard {
            chatCardHeader(icon: "leaf.fill", label: card.highlight ?? "Product", accent: SemanticColors.nutrient(.protein))
            HealthDivider()

            // Hero image — full width, tall. Tapping opens the rich detail sheet.
            ZStack(alignment: .topTrailing) {
                ZStack {
                    if let url = card.imageUrl, let u = URL(string: url) {
                        AsyncImage(url: u) { phase in
                            if let img = phase.image {
                                img.resizable().scaledToFill()
                            } else if phase.error != nil {
                                productPlaceholderLarge
                            } else {
                                ProgressView()
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .background(AppColors.textSecondary.opacity(0.06))
                            }
                        }
                    } else {
                        productPlaceholderLarge
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 180)
                .clipped()
                .contentShape(Rectangle())
                .onTapGesture { showingDetail = true }

                // Floating "info" hint
                HStack(spacing: 4) {
                    Image(systemName: "info.circle.fill")
                    Text(l10n.t("chat.action.moreInfo"))
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.25), lineWidth: 0.5))
                .padding(10)
                .allowsHitTesting(false)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(card.name)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppColors.textPrimary)
                macroRow(card: card)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, 12)

            // Action row
            if onAction != nil {
                HealthDivider()
                HStack(spacing: 8) {
                    // Prefer backend-driven actions; fall back to defaults
                    // while servers roll out the new schema.
                    let backend = (card.actions ?? []).compactMap { ChatAction.from(backend: $0, product: card) }
                    if !backend.isEmpty {
                        ForEach(Array(backend.enumerated()), id: \.offset) { i, action in
                            ChatActionButton(
                                title: productActionTitle(action),
                                icon:  productActionIcon(action),
                                style: i == 0 ? .primary : .secondary
                            ) { onAction?(action) }
                        }
                    } else {
                        ChatActionButton(
                            title: l10n.t("chat.action.addToCart"),
                            icon: "cart.badge.plus",
                            style: .primary
                        ) {
                            onAction?(.addProductToShopping(card))
                        }
                        ChatActionButton(
                            title: l10n.t("chat.action.showRecipes"),
                            icon: "fork.knife",
                            style: .secondary
                        ) {
                            onAction?(.showRecipesFor(product: card))
                        }
                    }
                }
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, 10)

                // Secondary row: "Add to stock" — always available so the
                // user can drop a product straight into inventory from chat.
                HStack(spacing: 8) {
                    ChatActionButton(
                        title: l10n.t("chat.action.addToInventory"),
                        icon: "tray.and.arrow.down.fill",
                        style: .secondary
                    ) {
                        onAction?(.addProductToInventory(card))
                    }
                    ChatActionButton(
                        title: l10n.t("chat.action.moreInfo"),
                        icon: "info.circle",
                        style: .secondary
                    ) {
                        showingDetail = true
                    }
                }
                .padding(.horizontal, Spacing.sm)
                .padding(.bottom, 10)
            }
        }
        .sheet(isPresented: $showingDetail) {
            IngredientDetailSheet(slug: card.slug, fallbackName: card.name, fallbackImageUrl: card.imageUrl)
                .environmentObject(l10n)
        }
    }

    private func productActionTitle(_ a: ChatAction) -> String {
        switch a {
        case .addProductToShopping:  return l10n.t("chat.action.addToCart")
        case .addProductToInventory: return l10n.t("chat.action.addToInventory")
        case .showRecipesFor:        return l10n.t("chat.action.showRecipes")
        default:                     return ""
        }
    }

    private func productActionIcon(_ a: ChatAction) -> String {
        switch a {
        case .addProductToShopping:  return "cart.badge.plus"
        case .addProductToInventory: return "tray.and.arrow.down.fill"
        case .showRecipesFor:        return "fork.knife"
        default:                     return "questionmark"
        }
    }

    private var productPlaceholder: some View {
        Image(systemName: "fork.knife")
            .font(.title3)
            .foregroundStyle(AppColors.textSecondary)
            .frame(width: 60, height: 60)
            .background(AppColors.textSecondary.opacity(0.08), in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
    }

    private var productPlaceholderLarge: some View {
        ZStack {
            AppColors.textSecondary.opacity(0.08)
            Image(systemName: "fork.knife")
                .font(.system(size: 42, weight: .light))
                .foregroundStyle(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func macroRow(card: APIClient.BackendProductCard) -> some View {
        HStack(spacing: 10) {
            macroPill(value: card.caloriesPer100g, unit: "kcal", color: SemanticColors.nutrient(.calories))
            macroPill(value: card.proteinPer100g, unit: "P", color: SemanticColors.nutrient(.protein))
            macroPill(value: card.fatPer100g, unit: "F", color: SemanticColors.nutrient(.fat))
            macroPill(value: card.carbsPer100g, unit: "C", color: SemanticColors.nutrient(.carbs))
        }
    }

    private func macroPill(value: Double, unit: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Text(String(format: "%.0f", value))
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(unit)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppColors.textSecondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.10), in: Capsule())
    }
}

// MARK: - NutritionBotCard

struct NutritionBotCard: View {
    let card: APIClient.BackendNutritionCard

    var body: some View {
        ChatCard {
            chatCardHeader(icon: "chart.pie.fill", label: "Nutrition · per 100g", accent: SemanticColors.nutrient(.calories))
            HealthDivider()
            VStack(alignment: .leading, spacing: 8) {
                Text(card.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppColors.textPrimary)
                HStack(spacing: 0) {
                    macroCell(value: card.caloriesPer100g, label: "kcal", color: SemanticColors.nutrient(.calories))
                    Divider().frame(height: 36)
                    macroCell(value: card.proteinPer100g, label: "Protein", color: SemanticColors.nutrient(.protein))
                    Divider().frame(height: 36)
                    macroCell(value: card.fatPer100g, label: "Fat", color: SemanticColors.nutrient(.fat))
                    Divider().frame(height: 36)
                    macroCell(value: card.carbsPer100g, label: "Carbs", color: SemanticColors.nutrient(.carbs))
                }
                .padding(.top, 2)
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, 12)
        }
    }

    private func macroCell(value: Double, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(String(format: "%.1f", value))
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - CookingLossBotCard

/// Displays per-state cooking-loss table: weight change, water loss, oil absorbed, kcal.
struct CookingLossBotCard: View {
    let card: APIClient.BackendCookingLossCard

    var body: some View {
        ChatCard {
            chatCardHeader(icon: "flame.fill", label: "Cooking loss · per 100g raw", accent: .orange)
            HealthDivider()
            VStack(alignment: .leading, spacing: 10) {
                Text(card.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppColors.textPrimary)

                ForEach(card.rows, id: \.state) { row in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(row.label.capitalized)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(AppColors.textPrimary)
                            Spacer()
                            if let k = row.caloriesPer100g {
                                Text("\(Int(k.rounded())) kcal")
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundStyle(SemanticColors.nutrient(.calories))
                            }
                        }
                        HStack(spacing: 12) {
                            if let w = row.weightChangePercent {
                                metricChip(icon: "scalemass",
                                           text: String(format: "%@%.0f%%", w < 0 ? "" : "+", w),
                                           color: w < 0 ? .orange : AppColors.textSecondary)
                            }
                            if let wl = row.waterLossPercent {
                                metricChip(icon: "drop",
                                           text: String(format: "−%.0f%%", wl),
                                           color: .blue)
                            }
                            if let oa = row.oilAbsorptionG, oa > 0 {
                                metricChip(icon: "drop.fill",
                                           text: String(format: "+%.1fg", oa),
                                           color: .yellow)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    if row.state != card.rows.last?.state {
                        HealthDivider()
                    }
                }

                Text("Percentages are measured against raw weight.")
                    .font(.system(size: 11))
                    .foregroundStyle(AppColors.textSecondary)
                    .padding(.top, 4)
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, 12)
        }
    }

    private func metricChip(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
            Text(text)
                .font(.system(size: 12, weight: .medium, design: .rounded))
        }
        .foregroundStyle(color)
    }
}

// MARK: - ConversionBotCard

struct ConversionBotCard: View {
    let card: APIClient.BackendConversionCard

    var body: some View {
        ChatCard {
            chatCardHeader(icon: "arrow.left.arrow.right", label: "Conversion", accent: AppColors.primary)
            HealthDivider()
            HStack(spacing: 0) {
                conversionSide(value: card.value, unit: card.from, isResult: false)
                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppColors.textSecondary)
                conversionSide(value: card.result, unit: card.to, isResult: true)
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, 14)
        }
    }

    private func conversionSide(value: Double, unit: String, isResult: Bool) -> some View {
        VStack(spacing: 2) {
            Text(String(format: value.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.2f", value))
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(isResult ? AppColors.primary : AppColors.textPrimary)
            Text(unit)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - RecipeBotCard

struct RecipeBotCard: View {
    let card: APIClient.BackendRecipeCard
    var onAction: ((ChatAction) -> Void)? = nil
    @State private var expanded = false
    @EnvironmentObject var l10n: LocalizationService

    var body: some View {
        ChatCard {
            chatCardHeader(icon: "frying.pan.fill", label: recipeLabel, accent: AppColors.accent)
            HealthDivider()

            // Title + complexity
            VStack(alignment: .leading, spacing: 4) {
                Text(card.displayName ?? card.dishNameLocal ?? card.dishName)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppColors.textPrimary)
                HStack(spacing: 8) {
                    complexityBadge
                    if !card.tags.isEmpty {
                        Text(card.tags.prefix(2).joined(separator: " · "))
                            .font(.system(size: 12))
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.top, 10)

            // Per-serving macros
            HStack(spacing: 0) {
                recipeCell(value: "\(card.perServingKcal)", label: "kcal", color: SemanticColors.nutrient(.calories))
                Divider().frame(height: 36)
                recipeCell(value: String(format: "%.0fg", card.perServingProtein), label: "Protein", color: SemanticColors.nutrient(.protein))
                Divider().frame(height: 36)
                recipeCell(value: String(format: "%.0fg", card.perServingFat), label: "Fat", color: SemanticColors.nutrient(.fat))
                Divider().frame(height: 36)
                recipeCell(value: String(format: "%.0fg", card.perServingCarbs), label: "Carbs", color: SemanticColors.nutrient(.carbs))
            }
            .padding(.vertical, 8)

            // Servings + total kcal footer
            HStack {
                Label("\(card.servings) servings", systemImage: "person.2")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
                Spacer()
                Text("Total \(card.totalKcal) kcal")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppColors.textSecondary)
            }
            .padding(.horizontal, Spacing.sm)

            // Ingredients expandable
            HealthDivider()
            Button {
                withAnimation(.snappy(duration: 0.3)) { expanded.toggle() }
            } label: {
                HStack {
                    Text(expanded ? "Hide ingredients" : "Show \(card.ingredients.count) ingredients")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppColors.primary)
                    Spacer()
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColors.primary)
                }
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, 10)
            }

            if expanded {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(card.ingredients.enumerated()), id: \.offset) { _, ing in
                        HStack(spacing: 8) {
                            Text(ing.name)
                                .font(.system(size: 13))
                                .foregroundStyle(AppColors.textPrimary)
                            Spacer()
                            Text("\(Int(ing.grossG))g")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(AppColors.textSecondary)
                            Text("· \(ing.kcal) kcal")
                                .font(.system(size: 11))
                                .foregroundStyle(AppColors.textSecondary)
                            if onAction != nil {
                                Button {
                                    onAction?(.swapIngredient(recipe: card, ingredient: ing.name))
                                } label: {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(AppColors.primary)
                                        .frame(width: 22, height: 22)
                                        .background(AppColors.primary.opacity(0.12), in: Circle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, Spacing.sm)
                .padding(.bottom, 10)
                .transition(.opacity.combined(with: .move(edge: .top)))

                // Steps (if any)
                if !card.steps.isEmpty {
                    HealthDivider()
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Steps")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppColors.textSecondary)
                            .padding(.horizontal, Spacing.sm)
                        ForEach(card.steps, id: \.step) { step in
                            HStack(alignment: .top, spacing: 10) {
                                Text("\(step.step)")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .frame(width: 22, height: 22)
                                    .background(AppColors.accent, in: Circle())
                                Text(step.text)
                                    .font(.system(size: 13))
                                    .foregroundStyle(AppColors.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.horizontal, Spacing.sm)
                        }
                    }
                    .padding(.bottom, 12)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }

            // Primary action row — always visible
            if onAction != nil {
                HealthDivider()
                HStack(spacing: 8) {
                    let backend = (card.actions ?? []).compactMap { ChatAction.from(backend: $0, recipe: card) }
                    if !backend.isEmpty {
                        ForEach(Array(backend.enumerated()), id: \.offset) { i, action in
                            ChatActionButton(
                                title: recipeActionTitle(action),
                                icon:  recipeActionIcon(action),
                                style: i == 0 ? .primary : .secondary
                            ) { onAction?(action) }
                        }
                    } else {
                        ChatActionButton(
                            title: l10n.t("chat.action.addToPlan"),
                            icon: "calendar.badge.plus",
                            style: .primary
                        ) {
                            onAction?(.addRecipeToPlan(card))
                        }
                        ChatActionButton(
                            title: l10n.t("chat.action.cook"),
                            icon: "flame.fill",
                            style: .secondary
                        ) {
                            onAction?(.startCooking(card))
                        }
                    }
                }
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, 10)
            }
        }
    }

    private func recipeActionTitle(_ a: ChatAction) -> String {
        switch a {
        case .addRecipeToPlan: return l10n.t("chat.action.addToPlan")
        case .startCooking:    return l10n.t("chat.action.cook")
        case .swapIngredient:  return l10n.t("chat.action.swap")
        default:               return ""
        }
    }

    private func recipeActionIcon(_ a: ChatAction) -> String {
        switch a {
        case .addRecipeToPlan: return "calendar.badge.plus"
        case .startCooking:    return "flame.fill"
        case .swapIngredient:  return "arrow.triangle.2.circlepath"
        default:               return "questionmark"
        }
    }

    private var recipeLabel: String {
        card.dishType.map { $0.capitalized + " Recipe" } ?? "Recipe"
    }

    private var complexityBadge: some View {
        let (color, icon): (Color, String) = {
            switch card.complexity {
            case "easy":   return (SemanticColors.nutrient(.protein), "tortoise.fill")
            case "hard":   return (AppColors.warning, "flame.fill")
            default:       return (AppColors.accent, "bolt.fill")
            }
        }()
        return Label(card.complexity.capitalized, systemImage: icon)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.1), in: Capsule())
    }

    private func recipeCell(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - ChatActionButton

/// Unified action button used across bot cards. Two visual weights.
struct ChatActionButton: View {
    enum Style { case primary, secondary }
    let title: String
    let icon: String
    let style: Style
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .foregroundStyle(style == .primary ? Color.white : AppColors.primary)
            .background(
                style == .primary
                    ? AnyShapeStyle(AppColors.primary)
                    : AnyShapeStyle(AppColors.primary.opacity(0.12)),
                in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - ConfirmationCard

/// Feedback card shown after a user-invoked action succeeds.
struct ConfirmationCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let tint: ConfirmationTint

    private var color: Color {
        switch tint {
        case .success: return SemanticColors.nutrient(.protein)
        case .info:    return AppColors.primary
        case .warning: return AppColors.warning
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 36, height: 36)
                .background(color.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppColors.textPrimary)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(2)
            }
            Spacer()
        }
        .padding(Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.surface)
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .stroke(color.opacity(0.25), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
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

