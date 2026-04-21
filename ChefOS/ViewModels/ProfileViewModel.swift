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
    @Published var profile: UserProfile = UserProfile()

    @Published var weightText: String = "70.0"
    @Published var ageText: String = "25"
    @Published var targetWeightText: String = "65.0"
    @Published var calorieText: String = "2200"
    @Published var proteinText: String = "120"
    @Published var mealsText: String = "3"

    @Published var newAllergy: String = ""
    @Published var newLike: String = ""
    @Published var newDislike: String = ""
    @Published var newCondition: String = ""

    @Published var autoSaved: Bool = false
    @Published var isLoading: Bool = false
    @Published var isSaving: Bool = false
    @Published var saveSuccess: Bool = false
    @Published var language: String = ""
    @Published var email: String = ""
    @Published var avatarUrl: String?

    private let api = APIClient.shared
    private var cancellables = Set<AnyCancellable>()
    private var baselineSignature = ""

    var hasUnsavedChanges: Bool {
        profileSignature != baselineSignature
    }

    init() {
        bindFormFields()
        baselineSignature = profileSignature
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            async let meTask = api.getMe()
            async let prefsTask = api.getPreferences()

            let me = try await meTask
            let prefs = try await prefsTask

            email = me.user.email
            avatarUrl = me.user.avatarUrl
            language = me.user.language

            profile.name = me.user.displayName ?? profile.name
            profile = Self.makeProfile(from: prefs, existing: profile)
            syncTextFieldsFromProfile()
            baselineSignature = profileSignature
        } catch {
            syncTextFieldsFromProfile()
        }
    }

    func save() {
        syncNumbers()
        let payload = Self.makePreferences(from: profile)

        isSaving = true
        saveSuccess = false

        Task {
            defer { isSaving = false }

            do {
                try await api.savePreferences(payload)
                baselineSignature = profileSignature
                withAnimation(.snappy(duration: 0.25)) {
                    saveSuccess = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                    guard let self else { return }
                    withAnimation(.easeOut(duration: 0.2)) {
                        self.saveSuccess = false
                    }
                }
            } catch {
                saveSuccess = false
            }
        }
    }

    func updateLanguage(_ code: String) {
        language = code

        Task {
            try? await api.updateLanguage(code)
        }
    }

    func uploadAvatar(image: UIImage) async {
        guard let data = image.jpegData(compressionQuality: 0.82) else { return }

        // Local fallback until direct binary upload is wired in the API client.
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".jpg")
        do {
            try data.write(to: tempURL, options: .atomic)
            avatarUrl = tempURL.absoluteString
        } catch {
            return
        }
    }

    func syncNumbers() {
        profile.weight = Double(weightText) ?? profile.weight
        profile.age = Int(ageText) ?? profile.age
        profile.targetWeight = Double(targetWeightText) ?? profile.targetWeight
        profile.calorieTarget = Int(calorieText) ?? profile.calorieTarget
        profile.proteinTarget = Int(proteinText) ?? profile.proteinTarget
        profile.mealsPerDay = Int(mealsText) ?? profile.mealsPerDay
    }

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

    private func bindFormFields() {
        $profile
            .dropFirst()
            .sink { [weak self] _ in
                self?.syncTextFieldsFromProfile()
                self?.showAutoSaved()
            }
            .store(in: &cancellables)
    }

    private func syncTextFieldsFromProfile() {
        ageText = "\(profile.age)"
        weightText = Self.decimalString(profile.weight)
        targetWeightText = Self.decimalString(profile.targetWeight)
        calorieText = "\(profile.calorieTarget)"
        proteinText = "\(profile.proteinTarget)"
        mealsText = "\(profile.mealsPerDay)"
    }

    private func showAutoSaved() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            autoSaved = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self else { return }
            withAnimation(.easeOut(duration: 0.2)) {
                self.autoSaved = false
            }
        }
    }

    private var profileSignature: String {
        [
            profile.name,
            "\(profile.age)",
            Self.decimalString(profile.weight),
            Self.decimalString(profile.targetWeight),
            "\(profile.calorieTarget)",
            "\(profile.proteinTarget)",
            "\(profile.mealsPerDay)",
            profile.goal.rawValue,
            profile.diet.rawValue,
            profile.preferredCuisine.rawValue,
            profile.cookingLevel.rawValue,
            profile.cookingTime.rawValue,
            language,
            profile.likes.joined(separator: "|"),
            profile.dislikes.joined(separator: "|"),
            profile.allergies.joined(separator: "|"),
            profile.intolerances.joined(separator: "|"),
            profile.medicalConditions.joined(separator: "|")
        ].joined(separator: "||")
    }

    private static func decimalString(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }
        return String(format: "%.1f", value)
    }

    private static func makeProfile(from dto: APIClient.UserPreferencesDTO, existing: UserProfile) -> UserProfile {
        var profile = existing
        profile.age = dto.age ?? profile.age
        profile.weight = dto.weight ?? profile.weight
        profile.targetWeight = dto.targetWeight ?? profile.targetWeight
        profile.goal = mapGoal(dto.goal) ?? profile.goal
        profile.calorieTarget = dto.calorieTarget
        profile.proteinTarget = dto.proteinTarget
        profile.mealsPerDay = dto.mealsPerDay
        profile.diet = mapDiet(dto.diet) ?? profile.diet
        profile.preferredCuisine = mapCuisine(dto.preferredCuisine) ?? profile.preferredCuisine
        profile.cookingLevel = mapCookingLevel(dto.cookingLevel) ?? profile.cookingLevel
        profile.cookingTime = mapCookingTime(dto.cookingTime) ?? profile.cookingTime
        profile.likes = dto.likes
        profile.dislikes = dto.dislikes
        profile.allergies = dto.allergies
        profile.intolerances = dto.intolerances
        profile.medicalConditions = dto.medicalConditions
        return profile
    }

    private static func makePreferences(from profile: UserProfile) -> APIClient.UserPreferencesDTO {
        APIClient.UserPreferencesDTO(
            age: profile.age,
            weight: profile.weight,
            targetWeight: profile.targetWeight,
            goal: backendGoal(profile.goal),
            calorieTarget: profile.calorieTarget,
            proteinTarget: profile.proteinTarget,
            mealsPerDay: profile.mealsPerDay,
            diet: backendDiet(profile.diet),
            preferredCuisine: backendCuisine(profile.preferredCuisine),
            cookingLevel: backendCookingLevel(profile.cookingLevel),
            cookingTime: backendCookingTime(profile.cookingTime),
            likes: profile.likes,
            dislikes: profile.dislikes,
            allergies: profile.allergies,
            intolerances: profile.intolerances,
            medicalConditions: profile.medicalConditions
        )
    }

    private static func mapGoal(_ value: String) -> UserProfile.FitnessGoal? {
        switch value {
        case "lose_weight", "lose_fat", "cut": .loseFat
        case "gain_muscle", "bulk": .gainMuscle
        case "maintain", "maintain_weight": .maintainWeight
        case "eat_healthier", "healthy": .eatHealthier
        case "medical_diet": .medicalDiet
        default: nil
        }
    }

    private static func mapDiet(_ value: String) -> UserProfile.DietType? {
        switch value {
        case "no_restrictions": .noRestrictions
        case "vegetarian": .vegetarian
        case "vegan": .vegan
        case "keto": .keto
        case "paleo": .paleo
        case "gluten_free": .glutenFree
        case "dairy_free": .dairyFree
        default: nil
        }
    }

    private static func mapCuisine(_ value: String) -> UserProfile.CuisineType? {
        switch value {
        case "asian": .asian
        case "mediterranean": .mediterranean
        case "american": .american
        case "mexican": .mexican
        case "italian": .italian
        case "middle_eastern": .middleEastern
        case "any": .any
        default: nil
        }
    }

    private static func mapCookingLevel(_ value: String) -> UserProfile.CookingLevel? {
        switch value {
        case "beginner": .beginner
        case "home_cook", "homeCook": .homeCook
        case "advanced": .advanced
        case "chef": .chef
        default: nil
        }
    }

    private static func mapCookingTime(_ value: String) -> UserProfile.CookingTime? {
        switch value {
        case "quick": .quick
        case "medium": .medium
        case "long": .long
        case "any": .any
        default: nil
        }
    }

    private static func backendGoal(_ value: UserProfile.FitnessGoal) -> String {
        switch value {
        case .loseFat: "lose_fat"
        case .gainMuscle: "gain_muscle"
        case .maintainWeight: "maintain_weight"
        case .eatHealthier: "eat_healthier"
        case .medicalDiet: "medical_diet"
        }
    }

    private static func backendDiet(_ value: UserProfile.DietType) -> String {
        switch value {
        case .noRestrictions: "no_restrictions"
        case .vegetarian: "vegetarian"
        case .vegan: "vegan"
        case .keto: "keto"
        case .paleo: "paleo"
        case .glutenFree: "gluten_free"
        case .dairyFree: "dairy_free"
        }
    }

    private static func backendCuisine(_ value: UserProfile.CuisineType) -> String {
        switch value {
        case .any: "any"
        case .asian: "asian"
        case .mediterranean: "mediterranean"
        case .american: "american"
        case .mexican: "mexican"
        case .italian: "italian"
        case .middleEastern: "middle_eastern"
        }
    }

    private static func backendCookingLevel(_ value: UserProfile.CookingLevel) -> String {
        switch value {
        case .beginner: "beginner"
        case .homeCook: "home_cook"
        case .advanced: "advanced"
        case .chef: "chef"
        }
    }

    private static func backendCookingTime(_ value: UserProfile.CookingTime) -> String {
        switch value {
        case .quick: "quick"
        case .medium: "medium"
        case .long: "long"
        case .any: "any"
        }
    }
}
