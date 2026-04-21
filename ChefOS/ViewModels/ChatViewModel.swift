//
//  ChatViewModel.swift
//  ChefOS
//

import Foundation
import Combine
import SwiftUI
import UIKit

// MARK: - ViewModels/Chat

final class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var draft: String = ""
    @Published var isThinking: Bool = false
    @Published var suggestions: [APIClient.ChatSuggestion] = []

    /// Session context for multi-turn conversation
    private var chatContext: APIClient.ChatContext = .empty()

    private let api = APIClient.shared
    private let l10n = LocalizationService.shared
    private let userId: String?

    init() {
        userId = AuthService.readCurrentUserId()
        messages = [
            Message(content: .text(l10n.t("chat.welcome")), isFromUser: false)
        ]
        // Load preferences and show personalized greeting
        Task { @MainActor in
            await loadPersonalizedGreeting()
        }
    }

    @MainActor
    private func loadPersonalizedGreeting() async {
        guard userId != nil else { return }
        do {
            async let meResult = api.getMe()
            async let prefsResult = api.getPreferences()
            let me = try await meResult
            let prefs = try await prefsResult
            let name = me.user.displayName ?? ""

            // Replace generic welcome with structured greeting cards (staggered)
            messages.removeAll()

            // Card 1 — greeting (immediate)
            withAnimation(.snappy(duration: 0.35)) {
                messages.append(Message(content: .text(""), isFromUser: false,
                                        cardType: .greeting(name: name)))
            }

            // Card 2 — goal
            try await Task.sleep(nanoseconds: 500_000_000)
            withAnimation(.snappy(duration: 0.35)) {
                messages.append(Message(content: .text(""), isFromUser: false,
                                        cardType: .goal(goal: goalDisplayName(prefs.goal),
                                                        focus: goalFocus(prefs.goal))))
            }

            // Card 3 — targets
            try await Task.sleep(nanoseconds: 400_000_000)
            withAnimation(.snappy(duration: 0.35)) {
                messages.append(Message(content: .text(""), isFromUser: false,
                                        cardType: .dailyTargets(kcal: prefs.calorieTarget,
                                                                protein: prefs.proteinTarget)))
            }

            // Card 4 — restrictions (only if allergies exist)
            if !prefs.allergies.isEmpty {
                try await Task.sleep(nanoseconds: 400_000_000)
                withAnimation(.snappy(duration: 0.35)) {
                    messages.append(Message(content: .text(""), isFromUser: false,
                                            cardType: .restrictions(items: prefs.allergies)))
                }
            }
        } catch {
            print("⚠️ Chat: failed to load prefs for greeting: \(error)")
        }
    }

    private func goalDisplayName(_ goal: String) -> String {
        switch goal {
        case "lose_weight", "low_calorie", "cut":    return l10n.t("chat.goal.loseWeight")
        case "gain_muscle", "high_protein", "bulk":  return l10n.t("chat.goal.gainMuscle")
        case "gain_weight", "mass":                  return l10n.t("chat.goal.gainWeight")
        case "eat_healthier":                        return l10n.t("chat.goal.eatHealthier")
        default:                                     return l10n.t("chat.goal.balanced")
        }
    }

    private func goalFocus(_ goal: String) -> String {
        switch goal {
        case "lose_weight", "low_calorie", "cut":    return l10n.t("chat.focus.loseWeight")
        case "gain_muscle", "high_protein", "bulk":  return l10n.t("chat.focus.gainMuscle")
        case "gain_weight", "mass":                  return l10n.t("chat.focus.gainWeight")
        case "eat_healthier":                        return l10n.t("chat.focus.eatHealthier")
        default:                                     return l10n.t("chat.focus.balanced")
        }
    }

    private func buildPersonalizedGreeting(_ p: APIClient.UserPreferencesDTO, userName: String) -> String {
        return "" // legacy — no longer called
    }

    func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        withAnimation(.snappy(duration: 0.35)) {
            messages.append(Message(content: .text(text), isFromUser: true))
        }
        draft = ""
        sendToBackend(text)
    }

    func sendSuggestion(_ query: String) {
        withAnimation(.snappy(duration: 0.35)) {
            messages.append(Message(content: .text(query), isFromUser: true))
        }
        sendToBackend(query)
    }

    func sendImage(_ image: UIImage) {
        withAnimation(.snappy(duration: 0.35)) {
            messages.append(Message(content: .image(image), isFromUser: true))
        }
        sendToBackend("I have a photo of food — what can I cook with these ingredients?")
    }

    func triggerAISuggestion() {
        withAnimation(.snappy(duration: 0.35)) {
            messages.append(Message(content: .text("Suggest something creative for dinner!"), isFromUser: true))
        }
        sendToBackend("Suggest something creative for dinner!")
    }

    // MARK: - Action Layer
    //
    // Cards dispatch user-initiated actions through this single entry point.
    // The ViewModel:
    //   1. Broadcasts a `Notification` so Plan/Shopping VMs can react
    //   2. Appends a confirmation card so the user sees immediate feedback
    //   3. Optionally triggers a follow-up chat query (e.g. "show recipes for X")

    @MainActor
    func handleAction(_ action: ChatAction) {
        let haptic = UIImpactFeedbackGenerator(style: .light)
        haptic.impactOccurred()

        switch action {
        case .addRecipeToPlan(let recipe):
            let name = recipe.displayName ?? recipe.dishNameLocal ?? recipe.dishName
            NotificationCenter.default.post(name: .chatDidAddRecipeToPlan, object: recipe)
            // Step 3: record the add in chat context so the next turn knows.
            // IMPORTANT: use `slug` (stable canonical id), NOT `name` —
            // localized/LLM-rephrased names are unstable across turns.
            recordAddedRecipe(recipe.slug)
            // Step 4: telemetry
            api.sendChatEvent(.actionClicked, userId: userId,
                cardType: "recipe", cardSlug: recipe.slug,
                actionType: "add_to_plan", lang: chatContext.lastLang)
            appendConfirmation(
                icon: "checkmark.circle.fill",
                title: l10n.t("chat.action.added.title"),
                subtitle: "\(name) · \(recipe.perServingKcal) kcal",
                tint: .success
            )

        case .startCooking(let recipe):
            let name = recipe.displayName ?? recipe.dishNameLocal ?? recipe.dishName
            NotificationCenter.default.post(name: .chatDidRequestCooking, object: recipe)
            api.sendChatEvent(.actionClicked, userId: userId,
                cardType: "recipe", cardSlug: recipe.slug,
                actionType: "start_cooking", lang: chatContext.lastLang)
            appendConfirmation(
                icon: "flame.fill",
                title: l10n.t("chat.action.cooking.title"),
                subtitle: "\(name) · \(recipe.steps.count) \(l10n.t("chat.action.steps"))",
                tint: .info
            )

        case .swapIngredient(let recipe, let ingredient):
            // Trigger a new chat turn — user wants an alternative
            let name = recipe.displayName ?? recipe.dishName
            api.sendChatEvent(.actionClicked, userId: userId,
                cardType: "recipe", cardSlug: recipe.slug,
                actionType: "swap_ingredient", lang: chatContext.lastLang)
            let query = l10n.t("chat.action.swap.query")
                .replacingOccurrences(of: "{ingredient}", with: ingredient)
                .replacingOccurrences(of: "{recipe}", with: name)
            sendSuggestion(query)

        case .addProductToShopping(let product):
            NotificationCenter.default.post(name: .chatDidAddToShoppingList, object: product)
            // Step 3: record the add so backend stops re-suggesting it.
            recordAddedProduct(product.slug)
            api.sendChatEvent(.actionClicked, userId: userId,
                cardType: "product", cardSlug: product.slug,
                actionType: "add_to_shopping", lang: chatContext.lastLang)
            appendConfirmation(
                icon: "cart.fill.badge.plus",
                title: l10n.t("chat.action.shopping.title"),
                subtitle: product.name,
                tint: .success
            )

        case .showRecipesFor(let product):
            api.sendChatEvent(.actionClicked, userId: userId,
                cardType: "product", cardSlug: product.slug,
                actionType: "show_recipes_for", lang: chatContext.lastLang)
            let query = l10n.t("chat.action.showRecipes.query")
                .replacingOccurrences(of: "{product}", with: product.name)
            sendSuggestion(query)
        }
    }

    /// Step 3: append a recipe id to chatContext.addedRecipes (deduplicated, capped).
    private func recordAddedRecipe(_ id: String) {
        var list = chatContext.addedRecipes ?? []
        if !list.contains(id) {
            list.append(id)
            // Cap to keep payload small — server contract caps at 20.
            if list.count > 20 { list.removeFirst(list.count - 20) }
            chatContext.addedRecipes = list
        }
    }

    /// Step 3: append a product slug to chatContext.addedProducts (dedup, capped).
    private func recordAddedProduct(_ slug: String) {
        var list = chatContext.addedProducts ?? []
        if !list.contains(slug) {
            list.append(slug)
            if list.count > 30 { list.removeFirst(list.count - 30) }
            chatContext.addedProducts = list
        }
    }

    @MainActor
    private func appendConfirmation(icon: String, title: String, subtitle: String, tint: ConfirmationTint) {
        withAnimation(.snappy(duration: 0.35)) {
            messages.append(Message(
                content: .text(""),
                isFromUser: false,
                cardType: .confirmation(icon: icon, title: title, subtitle: subtitle, tint: tint)
            ))
        }
    }

    // MARK: - Backend Integration (POST /public/chat → RuleBot)

    private func sendToBackend(_ input: String) {
        withAnimation(.easeOut(duration: 0.25)) {
            isThinking = true
            suggestions = []
        }

        // Pass user's preferred language in context
        if chatContext.lastLang == nil || chatContext.lastLang?.isEmpty == true {
            chatContext.lastLang = l10n.language
        }

        // Step 4: telemetry — record user query before we send it.
        api.sendChatEvent(
            .querySent,
            userId: userId,
            query: input,
            lang: chatContext.lastLang
        )

        Task { @MainActor in
            do {
                let response = try await api.sendChat(input: input, context: chatContext, userId: userId)

                withAnimation(.easeOut(duration: 0.2)) {
                    self.isThinking = false
                }

                // ── 1. Text reply ────────────────────────────────────────
                // Always show main text. Append chef_tip / coach_message only
                // when there are no rich cards (LLM fallback / Unknown intent).
                let hasCards = !(response.cards ?? []).isEmpty
                var responseText = response.text
                if !hasCards {
                    if let tip = response.chefTip, !tip.isEmpty {
                        responseText += "\n\n🍳 \(tip)"
                    }
                    if let coach = response.coachMessage, !coach.isEmpty {
                        responseText += "\n\n💬 \(coach)"
                    }
                    if let reason = response.reason, !reason.isEmpty {
                        responseText += "\n\n💡 \(reason)"
                    }
                }

                if !responseText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    withAnimation(.snappy(duration: 0.35)) {
                        self.messages.append(Message(content: .text(responseText), isFromUser: false))
                    }
                }

                // ── 2. Rich cards (staggered) ────────────────────────────
                if let cards = response.cards, !cards.isEmpty {
                    for (i, card) in cards.enumerated() {
                        let delay: UInt64 = UInt64(i) * 200_000_000
                        if delay > 0 { try await Task.sleep(nanoseconds: delay) }
                        let cardType: ChatCardType = {
                            switch card {
                            case .product(let p):    return .product(p)
                            case .nutrition(let n):  return .nutrition(n)
                            case .conversion(let c): return .conversion(c)
                            case .recipe(let r):     return .recipe(r)
                            case .unknown:           return .none
                            }
                        }()
                        if case .none = cardType { continue }
                        withAnimation(.snappy(duration: 0.35)) {
                            self.messages.append(Message(content: .text(""), isFromUser: false, cardType: cardType))
                        }
                    }
                }

                if let suggs = response.suggestions, !suggs.isEmpty {
                    withAnimation(.easeOut(duration: 0.3)) {
                        self.suggestions = suggs
                    }
                }

                if let ctx = response.context {
                    self.chatContext = ctx
                }

            } catch {
                withAnimation(.easeOut(duration: 0.2)) {
                    self.isThinking = false
                }
                #if DEBUG
                print("❌ [ChatVM] sendChat failed: \(error)")
                #endif
                let userMessage: String = {
                    if let apiErr = error as? APIError {
                        switch apiErr {
                        case .networkError:
                            return self.l10n.t("chat.error.network")
                        case .rateLimited:
                            return self.l10n.t("chat.error.rate_limited")
                        case .serverError(let code, let msg):
                            #if DEBUG
                            return "⚠️ \(code): \(msg)"
                            #else
                            return self.l10n.t("chat.error.server")
                            #endif
                        case .validation(let msg):
                            return msg
                        case .unauthorized:
                            return self.l10n.t("chat.error.unauthorized")
                        }
                    }
                    if error is URLError {
                        return self.l10n.t("chat.error.network")
                    }
                    #if DEBUG
                    return "⚠️ \(String(describing: error))"
                    #else
                    return self.l10n.t("chat.error")
                    #endif
                }()
                withAnimation(.snappy(duration: 0.35)) {
                    self.messages.append(Message(
                        content: .text(userMessage),
                        isFromUser: false
                    ))
                }
            }
        }
    }
}
