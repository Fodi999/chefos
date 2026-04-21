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

    /// Called after a successful token refresh so the caller can persist new tokens
    var onTokensRefreshed: ((_ access: String, _ refresh: String) -> Void)?

    /// Called when refresh fails and user must re-authenticate
    var onSessionExpired: (() -> Void)?

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
        onTokensRefreshed?(response.accessToken, response.refreshToken)
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
        try await executeVoid(request)
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
        try await executeVoid(request)
    }

    func updateLanguage(_ code: String) async throws {
        let requestUrl = URL(string: baseURL + "/profile/language")!
        var request = URLRequest(url: requestUrl)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(["language": code])
        try attachAuth(&request)
        try await executeVoid(request)
    }

    // MARK: - Catalog Endpoints

    struct CatalogCategoryDTO: Codable, Identifiable {
        let id: String
        let name: String
        let sortOrder: Int
    }

    struct CatalogCategoriesResponse: Codable {
        let categories: [CatalogCategoryDTO]
    }

    struct CatalogIngredientDTO: Codable, Identifiable {
        let id: String
        let categoryId: String
        let name: String
        let defaultUnit: String
        let defaultShelfLifeDays: Int?
        let allergens: [String]
        let caloriesPer100g: Double?
        let seasons: [String]
        let imageUrl: String?
    }

    struct CatalogIngredientsResponse: Codable {
        let ingredients: [CatalogIngredientDTO]
    }

    func getCatalogCategories() async throws -> [CatalogCategoryDTO] {
        let response: CatalogCategoriesResponse = try await get("/catalog/categories")
        return response.categories
    }

    func searchCatalogIngredients(query: String? = nil, categoryId: String? = nil, limit: Int = 50) async throws -> [CatalogIngredientDTO] {
        var path = "/catalog/ingredients?limit=\(limit)"
        if let q = query, !q.isEmpty {
            path += "&q=\(q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? q)"
        }
        if let catId = categoryId {
            path += "&category_id=\(catId)"
        }
        let response: CatalogIngredientsResponse = try await get(path)
        return response.ingredients
    }

    // MARK: - Inventory Endpoints

    struct InventoryProductInfo: Codable {
        let id: String
        let name: String
        let category: String
        let baseUnit: String
        let imageUrl: String?
        let minStockThreshold: Double
    }

    struct InventoryItemDTO: Codable, Identifiable {
        let id: String
        let product: InventoryProductInfo
        let quantity: Double
        let remainingQuantity: Double
        let pricePerUnitCents: Int
        let severity: String          // "Ok", "Warning", "Critical", "Expired", "NoExpiration"
        let receivedAt: String
        let expiresAt: String
        let createdAt: String
        let updatedAt: String
    }

    struct InventoryListResponse: Codable {
        let items: [InventoryItemDTO]
        let total: Int
        let page: Int
        let perPage: Int
        let totalPages: Int
    }

    struct AddInventoryRequest: Codable {
        let catalogIngredientId: String
        let pricePerUnitCents: Int
        let quantity: Double
        let receivedAt: String
        let expiresAt: String
    }

    func listInventory(page: Int = 1, perPage: Int = 100) async throws -> InventoryListResponse {
        try await get("/inventory/products?page=\(page)&per_page=\(perPage)")
    }

    func addInventoryProduct(_ req: AddInventoryRequest) async throws -> InventoryItemDTO {
        try await post("/inventory/products", body: req)
    }

    func updateInventoryProduct(id: String, quantity: Double? = nil, priceCents: Int? = nil) async throws {
        let requestUrl = URL(string: baseURL + "/inventory/products/\(id)")!
        var request = URLRequest(url: requestUrl)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var body: [String: Any] = [:]
        if let q = quantity { body["quantity"] = q }
        if let p = priceCents { body["price_per_unit_cents"] = p }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        try attachAuth(&request)
        try await executeVoid(request)
    }

    func deleteInventoryProduct(id: String) async throws {
        let requestUrl = URL(string: baseURL + "/inventory/products/\(id)")!
        var request = URLRequest(url: requestUrl)
        request.httpMethod = "DELETE"
        try attachAuth(&request)
        try await executeVoid(request)
    }

    // MARK: - Cook Suggestions (POST /api/cook/suggestions)

    struct CookSuggestionsResponse: Codable {
        let inventoryInsight: InventoryInsight
        let canCook: [SuggestedDish]
        let almost: [SuggestedDish]
        let strategic: [SuggestedDish]
        let suggestions: UnlockSuggestions
        let personalization: PersonalizationInfo?
    }

    struct PersonalizationInfo: Codable {
        let personalized: Bool
        let goal: String
        let diet: String
        let kcalTarget: Int
        let proteinTarget: Int
        let excludedAllergens: [String]
        let excludedDislikes: [String]
    }

    struct InventoryInsight: Codable {
        let daysLeft: Int
        let atRisk: [String]
        let wasteRisk: Int
        let totalIngredients: Int
    }

    struct UnlockSuggestions: Codable {
        let missingFrequently: [String]
        let unlockHints: [String]
    }

    struct SuggestedDish: Codable, Identifiable {
        let id: UUID
        let dishName: String
        let dishNameLocal: String?
        let displayName: String?
        let dishType: String
        let complexity: String
        let ingredients: [SuggestedIngredient]
        let missingIngredients: [String]
        let missingCount: Int
        let totalKcal: Int
        let totalProteinG: Double
        let totalFatG: Double
        let totalCarbsG: Double
        let perServingKcal: Int
        let perServingProteinG: Double
        let perServingFatG: Double
        let perServingCarbsG: Double
        let servings: Int
        let steps: [RecipeStep]
        let insight: DishInsight
        let flavor: FlavorInfo?
        let adaptation: AdaptationInfo?
        let warnings: [String]
        let tags: [String]
        let allergens: [String]

        private enum CodingKeys: String, CodingKey {
            case dishName, dishNameLocal, displayName, dishType, complexity
            case ingredients, missingIngredients, missingCount
            case totalKcal, totalProteinG, totalFatG, totalCarbsG
            case perServingKcal, perServingProteinG, perServingFatG, perServingCarbsG
            case servings, steps, insight, flavor, adaptation
            case warnings, tags, allergens
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = UUID()
            dishName = try c.decode(String.self, forKey: .dishName)
            dishNameLocal = try c.decodeIfPresent(String.self, forKey: .dishNameLocal)
            displayName = try c.decodeIfPresent(String.self, forKey: .displayName)
            dishType = try c.decode(String.self, forKey: .dishType)
            complexity = try c.decode(String.self, forKey: .complexity)
            ingredients = try c.decode([SuggestedIngredient].self, forKey: .ingredients)
            missingIngredients = try c.decode([String].self, forKey: .missingIngredients)
            missingCount = try c.decode(Int.self, forKey: .missingCount)
            totalKcal = try c.decode(Int.self, forKey: .totalKcal)
            totalProteinG = try c.decode(Double.self, forKey: .totalProteinG)
            totalFatG = try c.decode(Double.self, forKey: .totalFatG)
            totalCarbsG = try c.decode(Double.self, forKey: .totalCarbsG)
            perServingKcal = try c.decode(Int.self, forKey: .perServingKcal)
            perServingProteinG = try c.decode(Double.self, forKey: .perServingProteinG)
            perServingFatG = try c.decode(Double.self, forKey: .perServingFatG)
            perServingCarbsG = try c.decode(Double.self, forKey: .perServingCarbsG)
            servings = try c.decode(Int.self, forKey: .servings)
            steps = try c.decode([RecipeStep].self, forKey: .steps)
            insight = try c.decode(DishInsight.self, forKey: .insight)
            flavor = try c.decodeIfPresent(FlavorInfo.self, forKey: .flavor)
            adaptation = try c.decodeIfPresent(AdaptationInfo.self, forKey: .adaptation)
            warnings = try c.decode([String].self, forKey: .warnings)
            tags = try c.decode([String].self, forKey: .tags)
            allergens = try c.decode([String].self, forKey: .allergens)
        }
    }

    struct RecipeStep: Codable, Identifiable {
        var id: Int { Int(step) }
        let step: Int
        let text: String
        let timeMin: Int?
        let tempC: Int?
        let tip: String?
    }

    struct SuggestedIngredient: Codable {
        let name: String
        let slug: String
        let grossG: Double
        let role: String
        let available: Bool
        let expiringSoon: Bool
        let productId: String?

        enum CodingKeys: String, CodingKey {
            case name, slug, grossG, role, available, expiringSoon, productId
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            name = try c.decode(String.self, forKey: .name)
            slug = try c.decode(String.self, forKey: .slug)
            grossG = try c.decode(Double.self, forKey: .grossG)
            role = try c.decode(String.self, forKey: .role)
            available = try c.decode(Bool.self, forKey: .available)
            expiringSoon = try c.decode(Bool.self, forKey: .expiringSoon)
            productId = try c.decodeIfPresent(String.self, forKey: .productId)
        }
    }

    struct DishInsight: Codable {
        let usesExpiring: Bool
        let highProtein: Bool
        let budgetFriendly: Bool
        let estimatedCostCents: Int
        let priorityScore: Int
        let reasons: [String]
    }

    struct FlavorInfo: Codable {
        let balanceScore: Double
        let dominant: String?
        let suggestions: [String]
    }

    struct AdaptationInfo: Codable {
        let changed: Bool
        let strategy: String?
        let actions: [String]
    }

    func getCookSuggestions() async throws -> CookSuggestionsResponse {
        let requestUrl = URL(string: baseURL + "/cook/suggestions")!
        var request = URLRequest(url: requestUrl)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        try attachAuth(&request)
        request.httpBody = try JSONEncoder().encode([:] as [String: String])
        let result: CookSuggestionsResponse = try await execute(request)
        print("✅ Parsed: canCook=\(result.canCook.count), almost=\(result.almost.count), strategic=\(result.strategic.count)")
        for dish in result.canCook + result.almost + result.strategic {
            print("  🍽 \(dish.dishName) | steps=\(dish.steps.count) | missing=\(dish.missingCount) | ingredients=\(dish.ingredients.count)")
        }
        return result
    }

    // MARK: - Chat Endpoints (RuleBot — POST /public/chat)

    struct ChatRequest: Codable {
        let input: String
        let context: ChatContext?
        let userId: String?
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

    struct ChatApiResponse: Decodable {
        let text: String
        let intent: String?
        let intents: [String]?
        let reason: String?
        let suggestions: [ChatSuggestion]?
        let chefTip: String?
        let coachMessage: String?
        let cards: [BackendCard]?
        let lang: String?
        let timingMs: Int?
        let context: ChatContext?
    }

    struct ChatSuggestion: Codable {
        let label: String
        let query: String
        let emoji: String?
    }

    // MARK: - Typed Backend Cards

    struct BackendProductCard: Decodable {
        let slug: String
        let name: String
        let caloriesPer100g: Double
        let proteinPer100g: Double
        let fatPer100g: Double
        let carbsPer100g: Double
        let imageUrl: String?
        let highlight: String?
        let reasonTag: String?
    }

    struct BackendNutritionCard: Decodable {
        let name: String
        let caloriesPer100g: Double
        let proteinPer100g: Double
        let fatPer100g: Double
        let carbsPer100g: Double
        let imageUrl: String?
    }

    struct BackendConversionCard: Decodable {
        let value: Double
        let from: String
        let to: String
        let result: Double
        let supported: Bool
    }

    struct BackendRecipeIngredient: Decodable {
        let name: String
        let slug: String?
        let state: String
        let role: String
        let grossG: Double
        let netG: Double
        let kcal: Int
        let proteinG: Double
        let fatG: Double
        let carbsG: Double
    }

    struct BackendRecipeStep: Decodable {
        let step: Int
        let text: String
        let timeMin: Int?
        let tempC: Int?
        let tip: String?
    }

    struct BackendRecipeCard: Decodable {
        let dishName: String
        let dishNameLocal: String?
        let displayName: String?
        let dishType: String?
        let servings: Int
        let ingredients: [BackendRecipeIngredient]
        let steps: [BackendRecipeStep]
        let totalKcal: Int
        let perServingKcal: Int
        let perServingProtein: Double
        let perServingFat: Double
        let perServingCarbs: Double
        let complexity: String
        let goal: String
        let allergens: [String]
        let tags: [String]
        let appliedConstraints: [String]
    }

    /// Tagged-union card from the backend `cards[]` array.
    /// Decoded based on the `"type"` discriminator field.
    enum BackendCard: Decodable {
        case product(BackendProductCard)
        case nutrition(BackendNutritionCard)
        case conversion(BackendConversionCard)
        case recipe(BackendRecipeCard)
        case unknown

        private enum TypeKey: CodingKey { case type }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: TypeKey.self)
            let type_ = try container.decodeIfPresent(String.self, forKey: .type) ?? "unknown"
            switch type_ {
            case "product":    self = .product(try BackendProductCard(from: decoder))
            case "nutrition":  self = .nutrition(try BackendNutritionCard(from: decoder))
            case "conversion": self = .conversion(try BackendConversionCard(from: decoder))
            case "recipe":     self = .recipe(try BackendRecipeCard(from: decoder))
            default:           self = .unknown
            }
        }
    }

    func sendChat(input: String, context: ChatContext?, userId: String? = nil) async throws -> ChatApiResponse {
        let body = ChatRequest(input: input, context: context, userId: userId)
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
        let data = try encoder.encode(body)
        request.httpBody = data
        
        #if DEBUG
        if let json = String(data: data, encoding: .utf8) {
            print("🚀 API POST [\(path)]: \(json)")
        }
        #endif
        
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
            // Only try refresh if the request was originally authenticated
            if request.value(forHTTPHeaderField: "Authorization") != nil,
               request.value(forHTTPHeaderField: "X-Retry") == nil {
                try await refreshAccessToken()
                var retryRequest = request
                retryRequest.setValue("true", forHTTPHeaderField: "X-Retry")
                try attachAuth(&retryRequest)
                return try await execute(retryRequest)
            }
            if request.url?.path.contains("/auth/login") == true {
                throw APIError.validation("Invalid email or password")
            }
            await MainActor.run { onSessionExpired?() }
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

    private func executeVoid(_ request: URLRequest) async throws {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.networkError
        }
        switch http.statusCode {
        case 200...299:
            return
        case 401:
            if request.value(forHTTPHeaderField: "X-Retry") == nil {
                try await refreshAccessToken()
                var retryRequest = request
                retryRequest.setValue("true", forHTTPHeaderField: "X-Retry")
                try attachAuth(&retryRequest)
                try await executeVoid(retryRequest)
                return
            }
            await MainActor.run { onSessionExpired?() }
            throw APIError.unauthorized
        default:
            if let errorBody = try? decoder.decode(APIErrorResponse.self, from: data) {
                throw APIError.serverError(http.statusCode, errorBody.details ?? errorBody.message)
            }
            throw URLError(.badServerResponse)
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
