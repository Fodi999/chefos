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
    @Published var messages: [Message] = [
        Message(content: .text("Hi! I'm your ChefOS assistant.\nWhat are we cooking today?"), isFromUser: false)
    ]
    @Published var draft: String = ""
    @Published var isThinking: Bool = false
    @Published var suggestions: [APIClient.ChatSuggestion] = []

    /// Session context for multi-turn conversation
    private var chatContext: APIClient.ChatContext = .empty()

    private let api = APIClient.shared

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

        Task { @MainActor in
            do {
                let response = try await api.sendChat(input: input, context: chatContext)

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
                        content: .text("Sorry, I couldn't reach the server. Check your connection and try again."),
                        isFromUser: false
                    ))
                }
            }
        }
    }
}
