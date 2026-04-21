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

        // `.convertFromSnakeCase` correctly handles most fields
        // (`category_id` → `categoryId`), BUT breaks on digit boundaries:
        // `calories_per_100g` → `caloriesPer100G` (capital G). Pin the
        // POST-transformation key for that field only; let the strategy
        // handle the rest.
        private enum CodingKeys: String, CodingKey {
            case id, name, allergens, seasons
            case categoryId, defaultUnit, defaultShelfLifeDays, imageUrl
            case caloriesPer100g = "caloriesPer100G"
        }
    }

    // ───────────────────────────────────────────────────────────────────
    // Rich Wikipedia-style ingredient detail — /public/catalog/ingredients/:slug
    // Mirrors the Rust `NutritionProductDetail`. All fields are optional
    // because admin-filled tables may be sparse. `.convertFromSnakeCase` on
    // the shared decoder maps:
    //   protein_g        → proteinG
    //   vitamin_b12      → vitaminB12
    //   glycemic_index   → glycemicIndex
    //   best_cooking_method_ru → bestCookingMethodRu
    // so we can use plain Codable without explicit CodingKeys here.
    // ───────────────────────────────────────────────────────────────────
    struct IngredientDetailDTO: Decodable {
        let id: String
        let slug: String
        let nameEn: String?
        let nameRu: String?
        let namePl: String?
        let nameUk: String?
        let productType: String?
        let unit: String?
        let imageUrl: String?
        let descriptionEn: String?
        let descriptionRu: String?
        let descriptionPl: String?
        let descriptionUk: String?
        let densityGPerMl: Double?
        let typicalPortionG: Double?
        let edibleYieldPercent: Double?
        let shelfLifeDays: Int?
        let wildFarmed: String?
        let waterType: String?
        let sushiGrade: Bool?
        let substitutionGroup: String?
        let availabilityMonths: [Bool]?

        let macros: Macros?
        let vitamins: Vitamins?
        let minerals: Minerals?
        let fattyAcids: FattyAcids?
        let dietFlags: DietFlags?
        let allergens: Allergens?
        let foodProperties: FoodProperties?
        let culinary: Culinary?
        let culinaryBehavior: CulinaryBehavior?
        let healthProfile: HealthProfile?
        let sugarProfile: SugarProfile?
        let processingEffects: ProcessingEffects?

        struct Macros: Decodable {
            let caloriesKcal: Double?
            let proteinG: Double?
            let fatG: Double?
            let carbsG: Double?
            let fiberG: Double?
            let sugarG: Double?
            let starchG: Double?
            let waterG: Double?
            let alcoholG: Double?
        }
        struct Vitamins: Decodable {
            let vitaminA: Double?
            let vitaminC: Double?
            let vitaminD: Double?
            let vitaminE: Double?
            let vitaminK: Double?
            let vitaminB1: Double?
            let vitaminB2: Double?
            let vitaminB3: Double?
            let vitaminB5: Double?
            let vitaminB6: Double?
            let vitaminB7: Double?
            let vitaminB9: Double?
            let vitaminB12: Double?
        }
        struct Minerals: Decodable {
            let calcium: Double?
            let iron: Double?
            let magnesium: Double?
            let phosphorus: Double?
            let potassium: Double?
            let sodium: Double?
            let zinc: Double?
            let copper: Double?
            let manganese: Double?
            let selenium: Double?
        }
        struct FattyAcids: Decodable {
            let saturatedFat: Double?
            let monounsaturatedFat: Double?
            let polyunsaturatedFat: Double?
            let omega3: Double?
            let omega6: Double?
            let epa: Double?
            let dha: Double?
        }
        struct DietFlags: Decodable {
            let vegan: Bool?
            let vegetarian: Bool?
            let keto: Bool?
            let paleo: Bool?
            let glutenFree: Bool?
            let mediterranean: Bool?
            let lowCarb: Bool?
        }
        struct Allergens: Decodable {
            let milk: Bool?
            let fish: Bool?
            let shellfish: Bool?
            let nuts: Bool?
            let soy: Bool?
            let gluten: Bool?
            let eggs: Bool?
            let peanuts: Bool?
            let sesame: Bool?
            let celery: Bool?
            let mustard: Bool?
            let sulfites: Bool?
            let lupin: Bool?
            let molluscs: Bool?
        }
        struct FoodProperties: Decodable {
            let glycemicIndex: Double?
            let glycemicLoad: Double?
            let ph: Double?
            let smokePoint: Double?
            let waterActivity: Double?
        }
        struct Culinary: Decodable {
            let sweetness: Double?
            let acidity: Double?
            let bitterness: Double?
            let umami: Double?
            let aroma: Double?
            let texture: String?
        }
        struct CulinaryBehavior: Decodable {
            let behaviors: [CookingBehavior]
        }
        struct CookingBehavior: Decodable, Identifiable {
            var id: String { key }
            let key: String
            let type: String
            let effect: String?
            let trigger: String?
            let intensity: Double?
            let tempThreshold: Double?
            let targets: [String]?
            let polarity: String?
            let domain: String?
            let pairingScore: Double?
        }
        struct HealthProfile: Decodable {
            let bioactiveCompoundsEn: [String]?
            let bioactiveCompoundsRu: [String]?
            let bioactiveCompoundsPl: [String]?
            let bioactiveCompoundsUk: [String]?
            let healthEffectsEn: [String]?
            let healthEffectsRu: [String]?
            let healthEffectsPl: [String]?
            let healthEffectsUk: [String]?
            let contraindicationsEn: [String]?
            let contraindicationsRu: [String]?
            let contraindicationsPl: [String]?
            let contraindicationsUk: [String]?
            let foodRole: String?
            let oracScore: Double?
            let absorptionNotesEn: String?
            let absorptionNotesRu: String?
            let absorptionNotesPl: String?
            let absorptionNotesUk: String?
        }
        struct SugarProfile: Decodable {
            let glucose: Double?
            let fructose: Double?
            let sucrose: Double?
            let lactose: Double?
            let maltose: Double?
            let totalSugars: Double?
            let addedSugars: Double?
            let sweetnessPerception: Double?
            let sugarAlcohols: Double?
        }
        struct ProcessingEffects: Decodable {
            let vitaminRetentionPct: Double?
            let proteinDenatureTemp: Double?
            let mineralLeachingRisk: String?
            let bestCookingMethodEn: String?
            let bestCookingMethodRu: String?
            let bestCookingMethodPl: String?
            let bestCookingMethodUk: String?
            let maillardTemp: Double?
            let processingNotesEn: String?
            let processingNotesRu: String?
            let processingNotesPl: String?
            let processingNotesUk: String?
        }

        /// Best localized name for the current language.
        func localizedName(_ lang: String) -> String {
            switch lang {
            case "en": return nameEn ?? nameRu ?? slug
            case "pl": return namePl ?? nameEn ?? slug
            case "uk": return nameUk ?? nameRu ?? slug
            default:   return nameRu ?? nameEn ?? slug
            }
        }

        /// Best localized description.
        func localizedDescription(_ lang: String) -> String? {
            switch lang {
            case "en": return descriptionEn ?? descriptionRu
            case "pl": return descriptionPl ?? descriptionEn
            case "uk": return descriptionUk ?? descriptionRu
            default:   return descriptionRu ?? descriptionEn
            }
        }
    }

    struct CatalogIngredientsResponse: Codable {
        let ingredients: [CatalogIngredientDTO]
    }

    // ───────────────────────────────────────────────────────────────────
    // Processing states (raw / boiled / steamed / baked / grilled / fried
    // / smoked / frozen / dried / pickled) — per-state macros, weight loss,
    // shelf life, storage temperature, texture, notes.
    // Backed by GET /public/ingredients/:slug/states (public, no auth).
    // ───────────────────────────────────────────────────────────────────
    struct IngredientStatesResponse: Decodable {
        let slug: String
        let ingredientId: String?
        let nameEn: String?
        let nameRu: String?
        let namePl: String?
        let nameUk: String?
        let imageUrl: String?
        let statesCount: Int?
        let states: [IngredientStateDTO]
    }

    struct IngredientStateDTO: Decodable, Identifiable {
        var id: String { state }
        let state: String                  // "raw" | "boiled" | ...
        let stateType: String?             // "natural" | "cooked" | ...
        let cookingMethod: String?
        let caloriesPer100g: Double?
        let proteinPer100g: Double?
        let fatPer100g: Double?
        let carbsPer100g: Double?
        let fiberPer100g: Double?
        let waterPercent: Double?
        let shelfLifeHours: Int?
        let storageTempC: Int?
        let texture: String?
        let weightChangePercent: Double?
        let waterLossPercent: Double?
        let oilAbsorptionG: Double?
        let glycemicIndex: Int?
        let nameSuffixEn: String?
        let nameSuffixRu: String?
        let nameSuffixPl: String?
        let nameSuffixUk: String?
        let notesEn: String?
        let notesRu: String?
        let notesPl: String?
        let notesUk: String?
        let dataScore: Double?

        // Explicit CodingKeys — `.convertFromSnakeCase` turns
        // `calories_per_100g` into `caloriesPer100G` (capital G),
        // so we must pin the exact post-conversion names.
        private enum CodingKeys: String, CodingKey {
            case state, stateType, cookingMethod
            case caloriesPer100g = "caloriesPer100G"
            case proteinPer100g  = "proteinPer100G"
            case fatPer100g      = "fatPer100G"
            case carbsPer100g    = "carbsPer100G"
            case fiberPer100g    = "fiberPer100G"
            case waterPercent, shelfLifeHours, storageTempC, texture
            case weightChangePercent, waterLossPercent, oilAbsorptionG, glycemicIndex
            case nameSuffixEn, nameSuffixRu, nameSuffixPl, nameSuffixUk
            case notesEn, notesRu, notesPl, notesUk
            case dataScore
        }

        /// Best localized suffix ("варёный", "boiled", "gotowany"…).
        func localizedSuffix(_ lang: String) -> String? {
            switch lang {
            case "en": return nameSuffixEn ?? nameSuffixRu
            case "pl": return nameSuffixPl ?? nameSuffixEn
            case "uk": return nameSuffixUk ?? nameSuffixRu
            default:   return nameSuffixRu ?? nameSuffixEn
            }
        }

        func localizedNotes(_ lang: String) -> String? {
            switch lang {
            case "en": return notesEn ?? notesRu
            case "pl": return notesPl ?? notesEn
            case "uk": return notesUk ?? notesRu
            default:   return notesRu ?? notesEn
            }
        }
    }

    func getCatalogCategories() async throws -> [CatalogCategoryDTO] {
        // Public endpoint — no JWT required. Language passed via query string.
        let response: CatalogCategoriesResponse = try await publicGet("/catalog/categories?lang=\(currentLang)")
        return response.categories
    }

    func searchCatalogIngredients(query: String? = nil, categoryId: String? = nil, limit: Int = 50) async throws -> [CatalogIngredientDTO] {
        var path = "/catalog/ingredients?lang=\(currentLang)&limit=\(limit)"
        if let q = query, !q.isEmpty {
            path += "&q=\(q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? q)"
        }
        if let catId = categoryId {
            path += "&category_id=\(catId)"
        }
        let response: CatalogIngredientsResponse = try await publicGet(path)
        return response.ingredients
    }

    /// Full Wikipedia-style nutrition detail for a single ingredient (by slug).
    /// Backed by `GET /public/catalog/ingredients/:slug` — no auth required.
    func getIngredientDetail(slug: String) async throws -> IngredientDetailDTO {
        let encoded = slug.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? slug
        return try await publicGet("/catalog/ingredients/\(encoded)")
    }

    /// Processing states (raw / boiled / fried / baked / etc.) for an
    /// ingredient, with weight-change %, shelf life and recalculated macros.
    /// Backed by `GET /public/ingredients/:slug/states` — slug-only (no UUID).
    func getIngredientStates(slug: String) async throws -> IngredientStatesResponse {
        let encoded = slug.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? slug
        return try await publicGet("/ingredients/\(encoded)/states?lang=\(currentLang)")
    }

    /// Best-effort UI language for public endpoints that take `?lang=…`.
    private var currentLang: String {
        let code = Locale.current.language.languageCode?.identifier.lowercased() ?? "ru"
        switch code {
        case "en", "pl", "uk", "ru": return code
        case "ua": return "uk"
        default:   return "ru"
        }
    }

    /// Plain GET against `/public/…` — no Authorization header, no refresh.
    /// Used for catalog browse (anonymous users).
    private func publicGet<T: Decodable>(_ path: String) async throws -> T {
        let url = URL(string: baseURL.replacingOccurrences(of: "/api", with: "") + "/public" + path)!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw APIError.networkError
        }
        return try decoder.decode(T.self, from: data)
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
        // ── Step 3 (stateful v1) — operational state ─────────────────
        // Filled by the client after the user actually executes an action.
        // Backend uses these to drop already-added items from suggestions
        // and to strip AddToPlan / AddToShopping from cards already added.
        var addedRecipes: [String]?
        var addedProducts: [String]?
        var lastCategory: String?

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
        /// Step 3.5 "Guidance": complementary cards block rendered as a
        /// separate section below main cards (e.g. Fish → Vegetable side).
        /// Never replaces `cards` — always additional.
        let suggestionBlock: SuggestionBlock?
        let chefTip: String?
        let coachMessage: String?
        let cards: [BackendCard]?
        let lang: String?
        let timingMs: Int?
        let context: ChatContext?
    }

    /// Complementary recommendation block — paired with primary cards.
    struct SuggestionBlock: Decodable {
        /// Localized heading: "Add a side", "Добавь гарнир", …
        let title: String
        /// Category slug of the suggested items ("vegetable", "fruit", …).
        let category: String
        /// Cards in the side block — same shape as primary `cards`.
        let items: [BackendCard]
    }

    struct ChatSuggestion: Codable {
        let label: String
        let query: String
        let emoji: String?
    }

    // MARK: - Typed Backend Cards

    /// Typed user-invokable action attached to a backend card.
    /// Tagged union matching the Rust `Action` enum on `/public/chat`.
    enum BackendAction: Decodable {
        case addToPlan(recipeId: String)
        case startCooking(recipeId: String)
        case swapIngredient(recipeId: String, ingredientSlug: String)
        case addToShopping(productSlug: String)
        case showRecipesFor(productSlug: String)
        case unknown

        private enum CodingKeys: String, CodingKey {
            case type
            case recipeId
            case ingredientSlug
            case productSlug
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            let type_ = (try? c.decode(String.self, forKey: .type)) ?? ""
            switch type_ {
            case "add_to_plan":
                self = .addToPlan(recipeId: (try? c.decode(String.self, forKey: .recipeId)) ?? "")
            case "start_cooking":
                self = .startCooking(recipeId: (try? c.decode(String.self, forKey: .recipeId)) ?? "")
            case "swap_ingredient":
                self = .swapIngredient(
                    recipeId: (try? c.decode(String.self, forKey: .recipeId)) ?? "",
                    ingredientSlug: (try? c.decode(String.self, forKey: .ingredientSlug)) ?? ""
                )
            case "add_to_shopping":
                self = .addToShopping(productSlug: (try? c.decode(String.self, forKey: .productSlug)) ?? "")
            case "show_recipes_for":
                self = .showRecipesFor(productSlug: (try? c.decode(String.self, forKey: .productSlug)) ?? "")
            default:
                self = .unknown
            }
        }
    }

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
        let actions: [BackendAction]?

        private enum CodingKeys: String, CodingKey {
            case slug, name
            // NOTE: the shared decoder has `.convertFromSnakeCase`, which
            // maps `calories_per_100g` → `caloriesPer100G` (capital G,
            // because "100g" is treated as a non-alphabetic prefix + 'g').
            // Our Swift property names use lowercase `g`, so we pin the
            // POST-transformation key here.
            case caloriesPer100g = "caloriesPer100G"
            case proteinPer100g  = "proteinPer100G"
            case fatPer100g      = "fatPer100G"
            case carbsPer100g    = "carbsPer100G"
            case imageUrl, highlight, reasonTag, actions
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            let slug   = (try? c.decode(String.self, forKey: .slug)) ?? ""
            let name   = (try? c.decode(String.self, forKey: .name)) ?? ""

            // Decode nutrition fields with per-field diagnostics.
            func decDouble(_ key: CodingKeys) -> Double {
                do { return try c.decode(Double.self, forKey: key) }
                catch {
                    #if DEBUG
                    print("⚠️ [BackendProductCard] '\(slug)' missing \(key.stringValue): \(error)")
                    #endif
                    return 0
                }
            }
            let kcal  = decDouble(.caloriesPer100g)
            let prot  = decDouble(.proteinPer100g)
            let fat   = decDouble(.fatPer100g)
            let carbs = decDouble(.carbsPer100g)
            let imgUrl    = try? c.decode(String.self, forKey: .imageUrl)
            let highlight = try? c.decode(String.self, forKey: .highlight)
            let reasonTag = try? c.decode(String.self, forKey: .reasonTag)
            let actions   = try? c.decode([BackendAction].self, forKey: .actions)

            self.slug            = slug
            self.name            = name
            self.caloriesPer100g = kcal
            self.proteinPer100g  = prot
            self.fatPer100g      = fat
            self.carbsPer100g    = carbs
            self.imageUrl        = imgUrl
            self.highlight       = highlight
            self.reasonTag       = reasonTag
            self.actions         = actions

            #if DEBUG
            print("🧩 [BackendProductCard] \(name) kcal=\(kcal) P=\(prot) F=\(fat) C=\(carbs) img=\(imgUrl ?? "nil")")
            #endif
        }
    }

    struct BackendNutritionCard: Decodable {
        let name: String
        let caloriesPer100g: Double
        let proteinPer100g: Double
        let fatPer100g: Double
        let carbsPer100g: Double
        let imageUrl: String?

        private enum CodingKeys: String, CodingKey {
            case name, imageUrl
            // `.convertFromSnakeCase` produces `caloriesPer100G` for
            // `calories_per_100g` — pin the post-transform key.
            case caloriesPer100g = "caloriesPer100G"
            case proteinPer100g  = "proteinPer100G"
            case fatPer100g      = "fatPer100G"
            case carbsPer100g    = "carbsPer100G"
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            self.name = (try? c.decode(String.self, forKey: .name)) ?? ""
            self.caloriesPer100g = (try? c.decode(Double.self, forKey: .caloriesPer100g)) ?? 0
            self.proteinPer100g  = (try? c.decode(Double.self, forKey: .proteinPer100g))  ?? 0
            self.fatPer100g      = (try? c.decode(Double.self, forKey: .fatPer100g))      ?? 0
            self.carbsPer100g    = (try? c.decode(Double.self, forKey: .carbsPer100g))    ?? 0
            self.imageUrl = try? c.decode(String.self, forKey: .imageUrl)
        }
    }

    struct BackendConversionCard: Decodable {
        let value: Double
        let from: String
        let to: String
        let result: Double
        let supported: Bool
    }

    /// One row in the cooking-loss table — per processing state.
    struct BackendCookingLossRow: Decodable {
        let state: String           // "boiled" | "fried" | "baked" | ...
        let label: String           // localized: "варёная" / "boiled" / ...
        let weightChangePercent: Double?
        let waterLossPercent: Double?
        let oilAbsorptionG: Double?
        let caloriesPer100g: Double?
        let proteinPer100g: Double?
        let fatPer100g: Double?
        let carbsPer100g: Double?

        // Explicit CodingKeys pin the post-`.convertFromSnakeCase`
        // names (e.g. `calories_per_100g` → `caloriesPer100G`).
        private enum CodingKeys: String, CodingKey {
            case state, label, weightChangePercent, waterLossPercent, oilAbsorptionG
            case caloriesPer100g = "caloriesPer100G"
            case proteinPer100g  = "proteinPer100G"
            case fatPer100g      = "fatPer100G"
            case carbsPer100g    = "carbsPer100G"
        }
    }

    struct BackendCookingLossCard: Decodable {
        let slug: String
        let name: String
        let rawCaloriesPer100g: Double
        let imageUrl: String?
        let rows: [BackendCookingLossRow]

        private enum CodingKeys: String, CodingKey {
            case slug, name, rows, imageUrl
            case rawCaloriesPer100g = "rawCaloriesPer100G"
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            self.slug = (try? c.decode(String.self, forKey: .slug)) ?? ""
            self.name = (try? c.decode(String.self, forKey: .name)) ?? ""
            self.rawCaloriesPer100g = (try? c.decode(Double.self, forKey: .rawCaloriesPer100g)) ?? 0
            self.imageUrl = try? c.decode(String.self, forKey: .imageUrl)
            self.rows = (try? c.decode([BackendCookingLossRow].self, forKey: .rows)) ?? []
        }
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
        /// Stable identifier — slugified canonical English `dish_name`.
        /// Use this (not displayName / dishNameLocal) for state tracking
        /// like `addedRecipes`, because localized/AI-rephrased names are
        /// unstable across turns.
        let slug: String
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
        let actions: [BackendAction]?
    }

    /// Tagged-union card from the backend `cards[]` array.
    /// Decoded based on the `"type"` discriminator field.
    enum BackendCard: Decodable {
        case product(BackendProductCard)
        case nutrition(BackendNutritionCard)
        case conversion(BackendConversionCard)
        case recipe(BackendRecipeCard)
        case cookingLoss(BackendCookingLossCard)
        case unknown

        private enum TypeKey: CodingKey { case type }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: TypeKey.self)
            let type_ = try container.decodeIfPresent(String.self, forKey: .type) ?? "unknown"
            // Resilient: if an individual card fails to decode (schema drift,
            // missing field, wrong type), fall back to `.unknown` so one bad
            // card does not invalidate the whole chat response.
            switch type_ {
            case "product":
                if let p = try? BackendProductCard(from: decoder) { self = .product(p) }
                else { Self.warn(type_, decoder); self = .unknown }
            case "nutrition":
                if let n = try? BackendNutritionCard(from: decoder) { self = .nutrition(n) }
                else { Self.warn(type_, decoder); self = .unknown }
            case "conversion":
                if let c = try? BackendConversionCard(from: decoder) { self = .conversion(c) }
                else { Self.warn(type_, decoder); self = .unknown }
            case "recipe":
                if let r = try? BackendRecipeCard(from: decoder) { self = .recipe(r) }
                else { Self.warn(type_, decoder); self = .unknown }
            case "cooking_loss":
                if let cl = try? BackendCookingLossCard(from: decoder) { self = .cookingLoss(cl) }
                else { Self.warn(type_, decoder); self = .unknown }
            default:
                #if DEBUG
                print("⚠️ [BackendCard] unknown card type: \(type_)")
                #endif
                self = .unknown
            }
        }

        private static func warn(_ type_: String, _ decoder: Decoder) {
            #if DEBUG
            print("⚠️ [BackendCard] failed to decode card type=\(type_) — degrading to .unknown")
            #endif
        }
    }

    func sendChat(input: String, context: ChatContext?, userId: String? = nil) async throws -> ChatApiResponse {
        let body = ChatRequest(input: input, context: context, userId: userId)
        // /public/chat is outside /api — use absolute path
        let url = URL(string: baseURL.replacingOccurrences(of: "/api", with: "") + "/public/chat")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let bodyData = try encoder.encode(body)
        request.httpBody = bodyData

        #if DEBUG
        print("➡️ [chat] POST \(url.absoluteString)")
        if let s = String(data: bodyData, encoding: .utf8) { print("➡️ [chat] body: \(s)") }
        #endif

        // Custom execute: keep full diagnostics instead of generic APIError.
        let started = Date()
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let urlErr as URLError {
            #if DEBUG
            print("❌ [chat] URLError: code=\(urlErr.code.rawValue) desc=\(urlErr.localizedDescription)")
            #endif
            throw APIError.networkError
        }
        let elapsed = Int(Date().timeIntervalSince(started) * 1000)

        guard let http = response as? HTTPURLResponse else {
            throw APIError.networkError
        }

        let raw = String(data: data, encoding: .utf8) ?? "<non-utf8 \(data.count) bytes>"
        #if DEBUG
        print("⬅️ [chat] status=\(http.statusCode) in \(elapsed)ms bytes=\(data.count)")
        print("⬅️ [chat] body: \(raw.prefix(800))\(raw.count > 800 ? "…" : "")")
        #endif

        guard (200...299).contains(http.statusCode) else {
            if let errorBody = try? decoder.decode(APIErrorResponse.self, from: data) {
                throw APIError.serverError(http.statusCode, errorBody.details ?? errorBody.message)
            }
            throw APIError.serverError(http.statusCode, "HTTP \(http.statusCode): \(raw.prefix(200))")
        }

        do {
            return try decoder.decode(ChatApiResponse.self, from: data)
        } catch let decErr as DecodingError {
            #if DEBUG
            print("❌ [chat] DecodingError: \(decErr)")
            #endif
            throw APIError.serverError(-1, "Decode error: \(Self.describe(decErr))")
        }
    }

    // MARK: - Chat Telemetry (Step 4)

    /// Event types accepted by `POST /public/chat/event`. Must match the
    /// backend whitelist in `chat_event_handler`. Wrong strings are
    /// rejected with 400 — enum forces compile-time correctness.
    enum ChatEventType: String, Encodable {
        case querySent          = "query_sent"
        case cardShown          = "card_shown"
        case cardDismissed      = "card_dismissed"
        case actionClicked      = "action_clicked"
        case suggestionClicked  = "suggestion_clicked"
    }

    struct ChatEventRequest: Encodable {
        let userId: String?
        let eventType: ChatEventType
        let sessionId: String?
        let cardType: String?
        let cardSlug: String?
        let actionType: String?
        let intent: String?
        let query: String?
        let lang: String?
    }

    /// Fire-and-forget telemetry — never throws to the UI. Logs on failure.
    /// Accepts 202 (normal) and 200; any other status is silently dropped.
    func sendChatEvent(
        _ eventType: ChatEventType,
        userId: String? = nil,
        sessionId: String? = nil,
        cardType: String? = nil,
        cardSlug: String? = nil,
        actionType: String? = nil,
        intent: String? = nil,
        query: String? = nil,
        lang: String? = nil
    ) {
        let body = ChatEventRequest(
            userId: userId,
            eventType: eventType,
            sessionId: sessionId,
            cardType: cardType,
            cardSlug: cardSlug,
            actionType: actionType,
            intent: intent,
            query: query,
            lang: lang
        )

        // Decouple from caller: always detached task, never blocking UI.
        Task.detached { [session, encoder, baseURL] in
            let url = URL(string: baseURL.replacingOccurrences(of: "/api", with: "") + "/public/chat/event")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            do {
                request.httpBody = try encoder.encode(body)
                _ = try await session.data(for: request)
            } catch {
                #if DEBUG
                print("⚠️ [chat/event] \(eventType.rawValue) dropped: \(error.localizedDescription)")
                #endif
            }
        }
    }

    private static func describe(_ err: DecodingError) -> String {
        switch err {
        case .typeMismatch(let t, let ctx):
            return "typeMismatch<\(t)> at \(ctx.codingPath.map { $0.stringValue }.joined(separator: ".")): \(ctx.debugDescription)"
        case .valueNotFound(let t, let ctx):
            return "valueNotFound<\(t)> at \(ctx.codingPath.map { $0.stringValue }.joined(separator: ".")): \(ctx.debugDescription)"
        case .keyNotFound(let k, let ctx):
            return "keyNotFound(\(k.stringValue)) at \(ctx.codingPath.map { $0.stringValue }.joined(separator: "."))"
        case .dataCorrupted(let ctx):
            return "dataCorrupted at \(ctx.codingPath.map { $0.stringValue }.joined(separator: ".")): \(ctx.debugDescription)"
        @unknown default:
            return "\(err)"
        }
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
