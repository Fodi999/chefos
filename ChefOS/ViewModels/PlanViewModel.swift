//
//  PlanViewModel.swift
//  ChefOS
//

import SwiftUI
import Combine

// MARK: - ViewModels/Plan

@MainActor
final class PlanViewModel: ObservableObject {
    @Published var weekDays: [MealPlanDay] = []
    @Published var selectedDayIndex: Int = 0
    @Published var isGenerating: Bool = false
    @Published var isOptimizing: Bool = false
    @Published var showWeekView: Bool = false
    @Published var showSuccessBanner: Bool = false
    @Published var revealedMealIndex: Int = -1
    @Published var showAddedToPlanBanner: Bool = false
    @Published var addedToPlanTitle: String = ""
    @Published var addedToPlanSlot: String = ""

    /// Cached backend dishes — real data from cook/suggestions
    @Published var availableRecipes: [Recipe] = []
    @Published var inventoryInsight: APIClient.InventoryInsight?
    @Published var apiError: String?

    // Targets from profile (hardcoded for now)
    let calorieTarget: Int = 2200
    let proteinTarget: Int = 140
    let budgetTarget: Double = 25.0  // per day

    /// Currency symbol — read from RegionService.shared
    var currency: String { RegionService.shared.currency }

    private let api = APIClient.shared

    var selectedDay: MealPlanDay {
        guard weekDays.indices.contains(selectedDayIndex) else { return .empty }
        return weekDays[selectedDayIndex]
    }

    var totalCalories: Int {
        selectedDay.meals.compactMap { $0.recipe?.calories }.reduce(0, +)
    }

    var totalProtein: Int {
        selectedDay.meals.compactMap { $0.recipe?.protein }.reduce(0, +)
    }

    var filledCount: Int {
        selectedDay.meals.filter { $0.recipe != nil }.count
    }

    var calorieProgress: Double {
        guard calorieTarget > 0 else { return 0 }
        return min(Double(totalCalories) / Double(calorieTarget), 1.0)
    }

    var proteinProgress: Double {
        guard proteinTarget > 0 else { return 0 }
        return min(Double(totalProtein) / Double(proteinTarget), 1.0)
    }

    var totalCost: Double {
        selectedDay.meals.compactMap { $0.recipe?.estimatedCost }.reduce(0, +)
    }

    var costProgress: Double {
        guard budgetTarget > 0 else { return 0 }
        return min(totalCost / budgetTarget, 1.0)
    }

    var budgetStatus: (text: String, color: Color) {
        let diff = budgetTarget - totalCost
        if totalCost == 0 { return ("No meals yet", .secondary) }
        if diff >= 0 { return ("Within budget", .green) }
        return ("Over budget by \(String(format: "%.0f", abs(diff))) \(currency)", .red)
    }

    // MARK: AI Insight

    var insight: (icon: String, text: String, color: Color) {
        if filledCount == 0 {
            if availableRecipes.isEmpty {
                return ("sparkles", "Tap Smart Plan to load recipes from your inventory", .orange)
            }
            return ("sparkles", "Tap Smart Plan to generate your day", .orange)
        }
        let calDiff = calorieTarget - totalCalories
        let protDiff = proteinTarget - totalProtein

        if filledCount == 3 && abs(calDiff) < 200 && abs(protDiff) < 20 {
            return ("hand.thumbsup.fill", "Balanced day — looking great!", .green)
        }
        if protDiff > 30 {
            return ("bolt.fill", "You're \(protDiff)g under your protein goal", .cyan)
        }
        if calDiff < -200 {
            return ("exclamationmark.triangle.fill", "Over calorie target by \(abs(calDiff)) kcal", .red)
        }
        if totalCost > budgetTarget {
            return ("banknote.fill", "Over budget by \(String(format: "%.0f", totalCost - budgetTarget)) \(currency) — try cheaper options", .red)
        }
        if filledCount < 3 {
            return ("fork.knife", "\(3 - filledCount) meal\(filledCount == 2 ? "" : "s") still empty", .secondary)
        }
        return ("checkmark.seal.fill", "On track for today's goals", .green)
    }

    // MARK: Week summary

    var weekCalories: Int {
        weekDays.flatMap { $0.meals }.compactMap { $0.recipe?.calories }.reduce(0, +)
    }

    var weekFilledMeals: Int {
        weekDays.flatMap { $0.meals }.filter { $0.recipe != nil }.count
    }

    var weekDaysCompleted: Int {
        weekDays.filter { day in
            day.meals.allSatisfy { $0.recipe != nil }
        }.count
    }

    // Meal icons for week preview
    func mealIcons(for day: MealPlanDay) -> [(symbol: String, filled: Bool)] {
        day.meals.map { meal in
            let filled = meal.recipe != nil
            switch meal.type {
            case .breakfast: return ("sun.horizon.fill", filled)
            case .lunch: return ("sun.max.fill", filled)
            case .dinner: return ("moon.stars.fill", filled)
            }
        }
    }

    private let calendar = Calendar.current

    init() {
        generateWeek()
    }

    private func generateWeek() {
        let today = Date.now
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today))!
        weekDays = (0..<7).map { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: startOfWeek)!
            return MealPlanDay(
                date: date,
                meals: Meal.MealType.allCases.map { type in
                    Meal(type: type, recipe: nil)
                }
            )
        }
        selectedDayIndex = weekDays.firstIndex { calendar.isDateInToday($0.date) } ?? 0
    }

    func selectDay(_ index: Int) {
        withAnimation(.snappy(duration: 0.35)) {
            selectedDayIndex = index
        }
    }

    func replaceMeal(at index: Int, with recipe: Recipe?) {
        guard weekDays.indices.contains(selectedDayIndex),
              weekDays[selectedDayIndex].meals.indices.contains(index) else { return }
        weekDays[selectedDayIndex].meals[index].recipe = recipe
    }

    func clearMeal(at index: Int) {
        replaceMeal(at: index, with: nil)
    }

    func autoFill() {
        guard weekDays.indices.contains(selectedDayIndex) else { return }
        let usedTitles = weekDays[selectedDayIndex].meals.compactMap { $0.recipe?.title }
        var used = usedTitles
        for i in weekDays[selectedDayIndex].meals.indices where weekDays[selectedDayIndex].meals[i].recipe == nil {
            let mealType = weekDays[selectedDayIndex].meals[i].type
            let recipe = pickRecipe(for: mealType, excluding: used)
            weekDays[selectedDayIndex].meals[i].recipe = recipe
            if let t = recipe?.title { used.append(t) }
        }
    }

    /// Fetch real recipes from cook/suggestions API
    func fetchRecipes() async {
        do {
            let response = try await api.getCookSuggestions()
            let allDishes = response.canCook + response.almost + response.strategic
            availableRecipes = allDishes.map { Recipe(from: $0) }
            inventoryInsight = response.inventoryInsight
            apiError = nil
            print("📋 Plan: loaded \(availableRecipes.count) recipes from backend")
        } catch {
            apiError = error.localizedDescription
            print("🔴 Plan: failed to fetch recipes: \(error)")
        }
    }

    /// Pick a recipe suited for a meal type, avoiding duplicates within the day
    private func pickRecipe(for mealType: Meal.MealType, excluding used: [String]) -> Recipe? {
        let pool = availableRecipes.filter { !used.contains($0.title) }
        guard !pool.isEmpty else { return availableRecipes.randomElement() }

        switch mealType {
        case .breakfast:
            return pool.sorted(by: { $0.calories < $1.calories }).first
        case .lunch:
            return pool.sorted(by: { $0.protein > $1.protein }).first
        case .dinner:
            let sorted = pool.sorted(by: { abs($0.calories - 500) < abs($1.calories - 500) })
            return sorted.first
        }
    }

    func generateDay() {
        isGenerating = true
        revealedMealIndex = -1
        let idx = selectedDayIndex
        guard weekDays.indices.contains(idx) else { return }

        Task {
            if availableRecipes.isEmpty {
                await fetchRecipes()
            }

            guard !availableRecipes.isEmpty else {
                self.isGenerating = false
                return
            }

            var usedTitles: [String] = []
            for i in weekDays[idx].meals.indices {
                let mealType = weekDays[idx].meals[i].type
                let recipe = pickRecipe(for: mealType, excluding: usedTitles)
                if let r = recipe { usedTitles.append(r.title) }

                try? await Task.sleep(nanoseconds: 400_000_000)

                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    self.weekDays[idx].meals[i].recipe = recipe
                    self.revealedMealIndex = i
                }

                if i == self.weekDays[idx].meals.count - 1 {
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    withAnimation(.snappy(duration: 0.4)) {
                        self.isGenerating = false
                        self.showSuccessBanner = true
                    }
                    try? await Task.sleep(nanoseconds: 2_500_000_000)
                    withAnimation(.easeOut(duration: 0.3)) {
                        self.showSuccessBanner = false
                    }
                }
            }
        }
    }

    func clearDay() {
        guard weekDays.indices.contains(selectedDayIndex) else { return }
        for i in weekDays[selectedDayIndex].meals.indices {
            weekDays[selectedDayIndex].meals[i].recipe = nil
        }
    }

    func optimizeDay() {
        guard weekDays.indices.contains(selectedDayIndex) else { return }
        isOptimizing = true

        Task {
            await fetchRecipes()

            try? await Task.sleep(nanoseconds: 500_000_000)

            guard !availableRecipes.isEmpty else {
                withAnimation { self.isOptimizing = false }
                return
            }

            let balanced = availableRecipes.sorted {
                let ratio0 = Double($0.protein) / max(Double($0.calories), 1)
                let ratio1 = Double($1.protein) / max(Double($1.calories), 1)
                return ratio0 > ratio1
            }

            withAnimation(.snappy(duration: 0.5)) {
                for i in self.weekDays[self.selectedDayIndex].meals.indices {
                    let pick = balanced[i % balanced.count]
                    self.weekDays[self.selectedDayIndex].meals[i].recipe = pick
                }
                self.isOptimizing = false
                self.showSuccessBanner = true
            }

            try? await Task.sleep(nanoseconds: 2_500_000_000)
            withAnimation(.easeOut(duration: 0.3)) {
                self.showSuccessBanner = false
            }
        }
    }

    /// Replace a single meal with a random real recipe from backend
    func replaceWithRandom(at index: Int) {
        guard weekDays.indices.contains(selectedDayIndex),
              weekDays[selectedDayIndex].meals.indices.contains(index) else { return }

        let mealType = weekDays[selectedDayIndex].meals[index].type
        let usedTitles = weekDays[selectedDayIndex].meals.compactMap { $0.recipe?.title }

        if availableRecipes.isEmpty {
            Task {
                await fetchRecipes()
                let recipe = pickRecipe(for: mealType, excluding: usedTitles)
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    self.weekDays[self.selectedDayIndex].meals[index].recipe = recipe
                }
            }
        } else {
            let recipe = pickRecipe(for: mealType, excluding: usedTitles)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                weekDays[selectedDayIndex].meals[index].recipe = recipe
            }
        }
    }

    func dayLetter(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "EEE"
        return String(formatter.string(from: date).prefix(3))
    }

    func dayNumber(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }

    func isToday(_ date: Date) -> Bool {
        calendar.isDateInToday(date)
    }

    func dayCalories(for day: MealPlanDay) -> Int {
        day.meals.compactMap { $0.recipe?.calories }.reduce(0, +)
    }

    func dayProtein(for day: MealPlanDay) -> Int {
        day.meals.compactMap { $0.recipe?.protein }.reduce(0, +)
    }

    func dayFilledCount(for day: MealPlanDay) -> Int {
        day.meals.filter { $0.recipe != nil }.count
    }

    func dayCost(for day: MealPlanDay) -> Double {
        day.meals.compactMap { $0.recipe?.estimatedCost }.reduce(0, +)
    }

    /// Check if a recipe is already in today's plan — returns meal type or nil
    func plannedSlot(for recipe: Recipe) -> String? {
        guard weekDays.indices.contains(selectedDayIndex) else { return nil }
        for meal in weekDays[selectedDayIndex].meals {
            if meal.recipe?.title == recipe.title {
                return meal.type.rawValue
            }
        }
        return nil
    }

    /// Empty meal slots for picker
    var emptySlots: [Meal] {
        guard weekDays.indices.contains(selectedDayIndex) else { return [] }
        return weekDays[selectedDayIndex].meals.filter { $0.recipe == nil }
    }

    /// Add a recipe to a specific meal slot
    func addRecipeToPlan(_ recipe: Recipe, mealType: Meal.MealType? = nil) {
        guard weekDays.indices.contains(selectedDayIndex) else { return }

        let targetIdx: Int?
        if let mt = mealType {
            targetIdx = weekDays[selectedDayIndex].meals.firstIndex(where: { $0.type == mt })
        } else {
            targetIdx = weekDays[selectedDayIndex].meals.firstIndex(where: { $0.recipe == nil })
        }

        guard let idx = targetIdx else { return }

        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            weekDays[selectedDayIndex].meals[idx].recipe = recipe
            addedToPlanTitle = recipe.title
            addedToPlanSlot = weekDays[selectedDayIndex].meals[idx].type.rawValue
            showAddedToPlanBanner = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.easeOut(duration: 0.3)) {
                self.showAddedToPlanBanner = false
            }
        }
    }
}
