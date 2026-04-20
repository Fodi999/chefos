//
//  ProfileViewModel.swift
//  ChefOS
//

import Foundation
import Combine
import SwiftUI
import UIKit

// MARK: - ViewModels/Profile

@MainActor
final class ProfileViewModel: ObservableObject {
    // Server-loaded user info
    @Published var email: String = ""
    @Published var displayName: String = ""
    @Published var avatarUrl: String?
    @Published var language: String = ""
    @Published var createdAt: String = ""
    @Published var role: String = ""
    @Published var tenantName: String = ""

    // Editable profile fields (synced with backend preferences)
    @Published var profile: UserProfile = UserProfile()

    @Published var weightText: String = "70.0"
    @Published var ageText: String = "25"
    @Published var targetWeightText: String = "65.0"
    @Published var calorieText: String = "2200"
    @Published var proteinText: String = "120"
    @Published var mealsText: String = "3"

    // Tag input fields
    @Published var newAllergy: String = ""
    @Published var newLike: String = ""
    @Published var newDislike: String = ""
    @Published var newCondition: String = ""

    @Published var autoSaved: Bool = false
    @Published var isSaving: Bool = false
    @Published var isLoading: Bool = false
    @Published var loadError: String?
    @Published var hasUnsavedChanges: Bool = false
    @Published var saveSuccess: Bool = false

    private let api = APIClient.shared
    private var cancellables = Set<AnyCancellable>()
    private var skipAutoSave = true

    init() {
        // Track changes for the save button
        $profile
            .dropFirst()
            .sink { [weak self] _ in
                guard let self, !self.skipAutoSave else { return }
                self.hasUnsavedChanges = true
            }
            .store(in: &cancellables)
    }

    // MARK: - Explicit Save

    func save() {
        syncNumbers()
        isSaving = true

        let dto = APIClient.UserPreferencesDTO(
            age: profile.age,
            weight: profile.weight,
            targetWeight: profile.targetWeight,
            goal: profile.goal.backendKey,
            calorieTarget: profile.calorieTarget,
            proteinTarget: profile.proteinTarget,
            mealsPerDay: profile.mealsPerDay,
            diet: profile.diet.backendKey,
            preferredCuisine: profile.preferredCuisine.backendKey,
            cookingLevel: profile.cookingLevel.backendKey,
            cookingTime: profile.cookingTime.backendKey,
            likes: profile.likes,
            dislikes: profile.dislikes,
            allergies: profile.allergies,
            intolerances: profile.intolerances,
            medicalConditions: profile.medicalConditions
        )

        Task {
            do {
                try await api.savePreferences(dto)
                isSaving = false
                hasUnsavedChanges = false
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    saveSuccess = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                    withAnimation { self?.saveSuccess = false }
                }
            } catch {
                isSaving = false
                print("⚠️ Failed to save preferences:", error)
            }
        }
    }

    // MARK: - Load from Backend

    func load() async {
        isLoading = true
        loadError = nil

        async let meResult = api.getMe()
        async let prefsResult = api.getPreferences()

        do {
            let me = try await meResult
            email = me.user.email
            displayName = me.user.displayName ?? ""
            avatarUrl = me.user.avatarUrl
            language = me.user.language
            createdAt = me.user.createdAt
            role = me.user.role
            tenantName = me.tenant.name
            profile.name = me.user.displayName ?? "User"
        } catch {
            print("⚠️ Failed to load /me:", error)
        }

        do {
            let prefs = try await prefsResult
            applyPreferences(prefs)
        } catch {
            print("⚠️ Failed to load /preferences:", error)
        }

        skipAutoSave = false
        isLoading = false
    }

    // MARK: - Language

    func updateLanguage(_ code: String) {
        Task {
            do {
                try await api.updateLanguage(code)
            } catch {
                print("⚠️ Failed to update language:", error)
            }
        }
    }

    // MARK: - Avatar Upload

    func uploadAvatar(image: UIImage) async {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }

        do {
            let upload = try await api.getAvatarUploadUrl(contentType: "image/jpeg")

            var request = URLRequest(url: URL(string: upload.uploadUrl)!)
            request.httpMethod = "PUT"
            request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
            request.httpBody = data
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                print("⚠️ R2 upload failed")
                return
            }

            try await api.updateAvatarUrl(upload.publicUrl)
            avatarUrl = upload.publicUrl
        } catch {
            print("⚠️ Avatar upload error:", error)
        }
    }

    // MARK: - Sync Numbers

    func syncNumbers() {
        profile.weight = Double(weightText) ?? profile.weight
        profile.age = Int(ageText) ?? profile.age
        profile.targetWeight = Double(targetWeightText) ?? profile.targetWeight
        profile.calorieTarget = Int(calorieText) ?? profile.calorieTarget
        profile.proteinTarget = Int(proteinText) ?? profile.proteinTarget
        profile.mealsPerDay = Int(mealsText) ?? profile.mealsPerDay
    }

    // MARK: - Tags

    func addTag(to keyPath: WritableKeyPath<UserProfile, [String]>, value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !profile[keyPath: keyPath].contains(trimmed) else { return }
        withAnimation(.snappy(duration: 0.25)) {
            profile[keyPath: keyPath].append(trimmed)
        }
    }

    func removeTag(from keyPath: WritableKeyPath<UserProfile, [String]>, value: String) {
        withAnimation(.snappy(duration: 0.25)) {
            profile[keyPath: keyPath].removeAll { $0 == value }
        }
    }

    // MARK: - Private

    private func applyPreferences(_ p: APIClient.UserPreferencesDTO) {
        if let age = p.age {
            profile.age = age
            ageText = "\(age)"
        }
        if let w = p.weight {
            profile.weight = w
            weightText = String(format: "%.1f", w)
        }
        if let tw = p.targetWeight {
            profile.targetWeight = tw
            targetWeightText = String(format: "%.1f", tw)
        }

        profile.calorieTarget = p.calorieTarget
        calorieText = "\(p.calorieTarget)"

        profile.proteinTarget = p.proteinTarget
        proteinText = "\(p.proteinTarget)"

        profile.mealsPerDay = p.mealsPerDay
        mealsText = "\(p.mealsPerDay)"

        profile.goal = UserProfile.FitnessGoal.from(backend: p.goal)
        profile.diet = UserProfile.DietType.from(backend: p.diet)
        profile.preferredCuisine = UserProfile.CuisineType.from(backend: p.preferredCuisine)
        profile.cookingLevel = UserProfile.CookingLevel.from(backend: p.cookingLevel)
        profile.cookingTime = UserProfile.CookingTime.from(backend: p.cookingTime)

        profile.likes = p.likes
        profile.dislikes = p.dislikes
        profile.allergies = p.allergies
        profile.intolerances = p.intolerances
        profile.medicalConditions = p.medicalConditions
    }

    private func showAutoSaved() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            autoSaved = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            withAnimation { self?.autoSaved = false }
        }
    }
}

// MARK: - Backend Key Mapping

extension UserProfile.FitnessGoal {
    var backendKey: String {
        switch self {
        case .loseFat: return "lose_fat"
        case .gainMuscle: return "gain_muscle"
        case .maintainWeight: return "maintain_weight"
        case .eatHealthier: return "eat_healthier"
        case .medicalDiet: return "medical_diet"
        }
    }
    static func from(backend key: String) -> Self {
        switch key {
        case "lose_fat": return .loseFat
        case "gain_muscle": return .gainMuscle
        case "maintain_weight": return .maintainWeight
        case "eat_healthier": return .eatHealthier
        case "medical_diet": return .medicalDiet
        default: return .eatHealthier
        }
    }
}

extension UserProfile.DietType {
    var backendKey: String {
        switch self {
        case .noRestrictions: return "no_restrictions"
        case .vegetarian: return "vegetarian"
        case .vegan: return "vegan"
        case .keto: return "keto"
        case .paleo: return "paleo"
        case .glutenFree: return "gluten_free"
        case .dairyFree: return "dairy_free"
        }
    }
    static func from(backend key: String) -> Self {
        switch key {
        case "no_restrictions": return .noRestrictions
        case "vegetarian": return .vegetarian
        case "vegan": return .vegan
        case "keto": return .keto
        case "paleo": return .paleo
        case "gluten_free": return .glutenFree
        case "dairy_free": return .dairyFree
        default: return .noRestrictions
        }
    }
}

extension UserProfile.CuisineType {
    var backendKey: String {
        switch self {
        case .any: return "any"
        case .asian: return "asian"
        case .mediterranean: return "mediterranean"
        case .american: return "american"
        case .mexican: return "mexican"
        case .italian: return "italian"
        case .middleEastern: return "middle_eastern"
        }
    }
    static func from(backend key: String) -> Self {
        switch key {
        case "asian": return .asian
        case "mediterranean": return .mediterranean
        case "american": return .american
        case "mexican": return .mexican
        case "italian": return .italian
        case "middle_eastern": return .middleEastern
        default: return .any
        }
    }
}

extension UserProfile.CookingLevel {
    var backendKey: String {
        switch self {
        case .beginner: return "beginner"
        case .homeCook: return "home_cook"
        case .advanced: return "advanced"
        case .chef: return "chef"
        }
    }
    static func from(backend key: String) -> Self {
        switch key {
        case "beginner": return .beginner
        case "home_cook": return .homeCook
        case "advanced": return .advanced
        case "chef": return .chef
        default: return .homeCook
        }
    }
}

extension UserProfile.CookingTime {
    var backendKey: String {
        switch self {
        case .quick: return "quick"
        case .medium: return "medium"
        case .long: return "long"
        case .any: return "any"
        }
    }
    static func from(backend key: String) -> Self {
        switch key {
        case "quick": return .quick
        case "medium": return .medium
        case "long": return .long
        default: return .any
        }
    }
}
