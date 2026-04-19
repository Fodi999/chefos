//
//  APIClient.swift
//  ChefOS
//

import Foundation

// MARK: - API Client (connects to Rust/Axum backend)

final class APIClient {
    static let shared = APIClient()

    // MARK: - Configuration

    private let baseURL = "https://ministerial-yetta-fodi999-c58d8823.koyeb.app/api"

    private var accessToken: String?
    private var refreshToken: String?

    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        session = URLSession(configuration: config)

        decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
    }

    // MARK: - Token Management

    func setTokens(access: String, refresh: String) {
        accessToken = access
        refreshToken = refresh
    }

    func clearTokens() {
        accessToken = nil
        refreshToken = nil
    }

    // MARK: - Auth Endpoints

    struct AuthResponse: Codable {
        let accessToken: String
        let refreshToken: String
        let tokenType: String
        let userId: String
        let tenantId: String
    }

    struct RegisterRequest: Codable {
        let email: String
        let password: String
        let restaurantName: String
        let ownerName: String?
        let language: String?
    }

    struct LoginRequest: Codable {
        let email: String
        let password: String
    }

    func register(email: String, password: String, name: String) async throws -> AuthResponse {
        let body = RegisterRequest(email: email, password: password, restaurantName: name, ownerName: name, language: nil)
        let response: AuthResponse = try await post("/auth/register", body: body, authenticated: false)
        setTokens(access: response.accessToken, refresh: response.refreshToken)
        return response
    }

    func login(email: String, password: String) async throws -> AuthResponse {
        let body = LoginRequest(email: email, password: password)
        let response: AuthResponse = try await post("/auth/login", body: body, authenticated: false)
        setTokens(access: response.accessToken, refresh: response.refreshToken)
        return response
    }

    func refreshAccessToken() async throws {
        guard let refresh = refreshToken else {
            throw APIError.unauthorized
        }
        let body = ["refresh_token": refresh]
        let response: AuthResponse = try await post("/auth/refresh", body: body, authenticated: false)
        setTokens(access: response.accessToken, refresh: response.refreshToken)
    }

    // MARK: - Usage Endpoints

    struct UsageTodayResponse: Codable {
        let plansLeft: Int
        let recipesLeft: Int
        let scansLeft: Int
        let optimizeLeft: Int
        let chatsLeft: Int
        let purchasedActions: Int
        let dailyLimits: DailyLimitsDTO
        let costs: CostsDTO
        let welcomeBonusGranted: Bool
    }

    struct DailyLimitsDTO: Codable {
        let plans: Int
        let recipes: Int
        let scans: Int
        let optimize: Int
        let chats: Int
    }

    struct CostsDTO: Codable {
        let generatePlan: Int
        let createRecipe: Int
        let scanReceipt: Int
        let optimizeDay: Int
        let aiChat: Int
    }

    struct UsageSnapshotDTO: Codable {
        let plansLeft: Int
        let recipesLeft: Int
        let scansLeft: Int
        let optimizeLeft: Int
        let chatsLeft: Int
        let purchasedActions: Int
    }

    struct ActionResponse: Codable {
        let allowed: Bool
        let source: String
        let reason: String?
        let remainingFree: Int
        let purchasedActionsLeft: Int
        let warning: Bool
        let message: String?
        let usage: UsageSnapshotDTO
    }

    struct BatchResponse: Codable {
        let results: [BatchItemDTO]
        let usage: UsageSnapshotDTO
    }

    struct BatchItemDTO: Codable {
        let action: String
        let allowed: Bool
        let source: String
        let reason: String?
        let message: String?
    }

    struct PurchaseResponse: Codable {
        let purchasedActions: Int
        let totalPurchased: Int
    }

    struct BonusResponse: Codable {
        let purchasedActions: Int
        let granted: Bool
    }

    func getUsageToday() async throws -> UsageTodayResponse {
        try await get("/usage/today")
    }

    func performAction(_ action: String, idempotencyKey: String = UUID().uuidString) async throws -> ActionResponse {
        try await postWithIdempotency("/usage/action", body: ["action": action], idempotencyKey: idempotencyKey)
    }

    func performBatch(_ actions: [String]) async throws -> BatchResponse {
        try await post("/usage/actions", body: ["actions": actions])
    }

    func recordPurchase(actions: Int, receiptId: String?) async throws -> PurchaseResponse {
        var body: [String: Any] = ["actions": actions]
        if let receipt = receiptId { body["receipt_id"] = receipt }
        return try await postRaw("/usage/purchase", body: body)
    }

    func grantWelcomeBonus() async throws -> BonusResponse {
        try await postEmpty("/usage/welcome-bonus")
    }

    // MARK: - Profile Endpoints

    struct MeResponse: Codable {
        let user: UserDTO
        let tenant: TenantDTO
    }

    struct UserDTO: Codable {
        let id: String
        let tenantId: String
        let email: String
        let displayName: String?
        let avatarUrl: String?
        let role: String
        let language: String
        let createdAt: String
    }

    struct TenantDTO: Codable {
        let id: String
        let name: String
        let createdAt: String
    }

    struct AvatarUploadResponse: Codable {
        let uploadUrl: String
        let publicUrl: String
    }

    struct UserPreferencesDTO: Codable {
        var age: Int?
        var weight: Double?
        var targetWeight: Double?

        var goal: String
        var calorieTarget: Int
        var proteinTarget: Int
        var mealsPerDay: Int

        var diet: String
        var preferredCuisine: String

        var cookingLevel: String
        var cookingTime: String

        var likes: [String]
        var dislikes: [String]
        var allergies: [String]
        var intolerances: [String]
        var medicalConditions: [String]
    }

    func getMe() async throws -> MeResponse {
        try await get("/me")
    }

    func getPreferences() async throws -> UserPreferencesDTO {
        try await get("/preferences")
    }

    func savePreferences(_ prefs: UserPreferencesDTO) async throws {
        let url = URL(string: baseURL + "/preferences")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(prefs)
        try attachAuth(&request)
        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    func getAvatarUploadUrl(contentType: String = "image/webp") async throws -> AvatarUploadResponse {
        try await get("/profile/avatar/upload-url?content_type=\(contentType)")
    }

    func updateAvatarUrl(_ url: String) async throws {
        let requestUrl = URL(string: baseURL + "/profile/avatar")!
        var request = URLRequest(url: requestUrl)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(["avatar_url": url])
        try attachAuth(&request)
        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    func updateLanguage(_ code: String) async throws {
        let requestUrl = URL(string: baseURL + "/profile/language")!
        var request = URLRequest(url: requestUrl)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(["language": code])
        try attachAuth(&request)
        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    // MARK: - Chat Endpoints (RuleBot — POST /public/chat)

    struct ChatRequest: Codable {
        let input: String
        let context: ChatContext?
    }

    struct ChatContext: Codable {
        var lastProductSlug: String?
        var lastProductName: String?
        var lastIntent: String?
        var lastModifier: String?
        var lastLang: String?
        var lastCards: [String]?
        var shownSlugs: [String]?
        var turnCount: Int

        static func empty() -> ChatContext {
            ChatContext(turnCount: 0)
        }
    }

    struct ChatApiResponse: Codable {
        let text: String
        let intent: String?
        let intents: [String]?
        let reason: String?
        let suggestions: [ChatSuggestion]?
        let chefTip: String?
        let coachMessage: String?
        let cards: [ChatCard]?
        let lang: String?
        let timingMs: Int?
        let context: ChatContext?
    }

    struct ChatSuggestion: Codable {
        let label: String
        let query: String
        let emoji: String?
    }

    struct ChatCard: Codable {
        let type: String?
        let slug: String?
        let name: String?
        let imageUrl: String?
        let highlight: String?
        let reasonTag: String?
        let caloriesPer100g: Double?
        let proteinPer100g: Double?
        let carbsPer100g: Double?
        let fatPer100g: Double?
    }

    func sendChat(input: String, context: ChatContext?) async throws -> ChatApiResponse {
        let body = ChatRequest(input: input, context: context)
        // /public/chat is outside /api — use absolute path
        let url = URL(string: baseURL.replacingOccurrences(of: "/api", with: "") + "/public/chat")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)
        return try await execute(request)
    }

    // MARK: - Generic Request Methods

    private func get<T: Decodable>(_ path: String) async throws -> T {
        let url = URL(string: baseURL + path)!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        try attachAuth(&request)
        return try await execute(request)
    }

    private func post<T: Decodable, B: Encodable>(_ path: String, body: B, authenticated: Bool = true) async throws -> T {
        let url = URL(string: baseURL + path)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)
        if authenticated { try attachAuth(&request) }
        return try await execute(request)
    }

    private func postWithIdempotency<T: Decodable, B: Encodable>(_ path: String, body: B, idempotencyKey: String) async throws -> T {
        let url = URL(string: baseURL + path)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(idempotencyKey, forHTTPHeaderField: "Idempotency-Key")
        request.httpBody = try encoder.encode(body)
        try attachAuth(&request)
        return try await execute(request)
    }

    private func postRaw<T: Decodable>(_ path: String, body: [String: Any]) async throws -> T {
        let url = URL(string: baseURL + path)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        try attachAuth(&request)
        return try await execute(request)
    }

    private func postEmpty<T: Decodable>(_ path: String) async throws -> T {
        let url = URL(string: baseURL + path)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = "{}".data(using: .utf8)
        try attachAuth(&request)
        return try await execute(request)
    }

    private func attachAuth(_ request: inout URLRequest) throws {
        guard let token = accessToken else { throw APIError.unauthorized }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }

    private func execute<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw APIError.networkError
        }

        switch http.statusCode {
        case 200...299:
            return try decoder.decode(T.self, from: data)
        case 401:
            // Try refresh once
            if request.value(forHTTPHeaderField: "X-Retry") == nil {
                try await refreshAccessToken()
                var retryRequest = request
                retryRequest.setValue("true", forHTTPHeaderField: "X-Retry")
                try attachAuth(&retryRequest)
                return try await execute(retryRequest)
            }
            throw APIError.unauthorized
        case 400, 422:
            // Try JSON first, then fall back to plain text
            if let errorBody = try? decoder.decode(APIErrorResponse.self, from: data) {
                let msg = errorBody.details ?? errorBody.message
                throw APIError.validation(msg)
            }
            let plainText = String(data: data, encoding: .utf8) ?? "Validation error"
            throw APIError.validation(plainText)
        case 429:
            throw APIError.rateLimited
        default:
            if let errorBody = try? decoder.decode(APIErrorResponse.self, from: data) {
                throw APIError.serverError(http.statusCode, errorBody.details ?? errorBody.message)
            }
            let plainText = String(data: data, encoding: .utf8) ?? "Server error"
            throw APIError.serverError(http.statusCode, plainText)
        }
    }
}

// MARK: - Error Types

enum APIError: Error, LocalizedError {
    case unauthorized
    case networkError
    case validation(String)
    case rateLimited
    case serverError(Int, String)

    var errorDescription: String? {
        switch self {
        case .unauthorized: return "Session expired. Please log in again."
        case .networkError: return "Network unavailable. Check your connection."
        case .validation(let msg): return msg
        case .rateLimited: return "Too many requests. Please wait."
        case .serverError(_, let msg): return msg
        }
    }
}

struct APIErrorResponse: Codable {
    let message: String
    let details: String?
    let code: String?
}
