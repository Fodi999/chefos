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
            // Fetch name + preferences in parallel
            async let meResult = api.getMe()
            async let prefsResult = api.getPreferences()

            let me = try await meResult
            let prefs = try await prefsResult

            let name = me.user.displayName ?? ""
            let greeting = buildPersonalizedGreeting(prefs, userName: name)
            if !greeting.isEmpty {
                // Replace the generic welcome with personalized one
                if !messages.isEmpty {
                    messages[0] = Message(
                        content: .text(l10n.t("chat.welcomePersonal")
                            .replacingOccurrences(of: "{name}", with: name.isEmpty ? "" : name)),
                        isFromUser: false
                    )
                }
                withAnimation(.snappy(duration: 0.35)) {
                    messages.append(Message(content: .text(greeting), isFromUser: false))
                }
            }
        } catch {
            print("⚠️ Chat: failed to load prefs for greeting: \(error)")
        }
    }

    private func buildPersonalizedGreeting(_ p: APIClient.UserPreferencesDTO, userName: String) -> String {
        var parts: [String] = []

        // Goal motivation
        switch p.goal {
        case "lose_weight", "low_calorie", "cut":
            parts.append(l10n.t("chat.motivation.loseWeight"))
        case "gain_muscle", "high_protein", "bulk":
            parts.append(l10n.t("chat.motivation.gainMuscle"))
        case "gain_weight", "mass":
            parts.append(l10n.t("chat.motivation.gainWeight"))
        case "eat_healthier":
            parts.append(l10n.t("chat.motivation.eatHealthier"))
        default:
            parts.append(l10n.t("chat.motivation.balanced"))
        }

        // Diet reminder
        if p.diet != "no_restrictions" && !p.diet.isEmpty {
            let dietName = p.diet.replacingOccurrences(of: "_", with: " ").capitalized
            parts.append(l10n.t("chat.motivation.diet").replacingOccurrences(of: "{diet}", with: dietName))
        }

        // Calorie / protein targets
        parts.append(l10n.t("chat.motivation.targets")
            .replacingOccurrences(of: "{kcal}", with: "\(p.calorieTarget)")
            .replacingOccurrences(of: "{protein}", with: "\(p.proteinTarget)"))

        // Allergies warning
        if !p.allergies.isEmpty {
            parts.append(l10n.t("chat.motivation.allergies").replacingOccurrences(of: "{list}", with: p.allergies.joined(separator: ", ")))
        }

        return parts.joined(separator: "\n")
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

        Task { @MainActor in
            do {
                let response = try await api.sendChat(input: input, context: chatContext, userId: userId)

                withAnimation(.easeOut(duration: 0.2)) {
                    self.isThinking = false
                }

                var responseText = response.text

                if let tip = response.chefTip {
                    responseText += "\n\n\(tip)"
                }
                if let coach = response.coachMessage {
                    responseText += "\n\n\(coach)"
                }
                if let reason = response.reason {
                    responseText += "\n\n💡 \(reason)"
                }

                withAnimation(.snappy(duration: 0.35)) {
                    self.messages.append(Message(content: .text(responseText), isFromUser: false))
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
                withAnimation(.snappy(duration: 0.35)) {
                    self.messages.append(Message(
                        content: .text(self.l10n.t("chat.error")),
                        isFromUser: false
                    ))
                }
            }
        }
    }
}
