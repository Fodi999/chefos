//
//  PlanViewModel.swift
//  ChefOS
//

import SwiftUI
import Combine

// MARK: - ViewModels/Plan

/// Calendar view mode — day / week / month. iOS 26 segmented style.
enum PlanMode: String, CaseIterable, Identifiable {
    case day, week, month
    var id: String { rawValue }
    var iconName: String {
        switch self {
        case .day:   return "calendar.day.timeline.left"
        case .week:  return "calendar"
        case .month: return "square.grid.3x3"
        }
    }
    var l10nKey: String {
        switch self {
        case .day:   return "plan.day"
        case .week:  return "plan.week"
        case .month: return "plan.month"
        }
    }
}

final class PlanViewModel: ObservableObject {
    @Published var weekDays: [MealPlanDay] = []
    @Published var selectedDayIndex: Int = 0
    @Published var isGenerating: Bool = false
    @Published var isOptimizing: Bool = false
    @Published var mode: PlanMode = .day
    @Published var showSuccessBanner: Bool = false
    @Published var revealedMealIndex: Int = -1
    @Published var showAddedToPlanBanner: Bool = false
    @Published var addedToPlanTitle: String = ""
    @Published var addedToPlanSlot: String = ""

    // Month view state
    @Published var visibleMonth: Date = Date.now
    /// Cache of meal plans keyed by start-of-day date. Populated from backend.
    @Published var monthPlans: [Date: MealPlanDay] = [:]
    @Published var isLoadingMonth: Bool = false

    // Back-compat shim — some older code still reads `showWeekView`
    var showWeekView: Bool {
        get { mode == .week }
        set { mode = newValue ? .week : .day }
    }

    // Targets from profile (hardcoded for now)
    let calorieTarget: Int = 2200
    let proteinTarget: Int = 140
    let budgetTarget: Double = 25.0  // per day

    /// Currency symbol — read from RegionService.shared
    var currency: String { RegionService.shared.currency }

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

    var budgetStatus: (key: String, args: [String], color: Color) {
        let diff = budgetTarget - totalCost
        if totalCost == 0 { return ("No meals yet", [], .secondary) }
        if diff >= 0 { return ("Within budget", [], .green) }
        return ("Over budget by \(String(format: "%.0f", abs(diff))) \(currency)", [], .red)
    }

    // MARK: AI Insight

    var insight: (icon: String, key: String, args: [String], color: Color) {
        if filledCount == 0 {
            return ("sparkles", "Tap Smart Plan to generate your day", [], .orange)
        }
        let calDiff = calorieTarget - totalCalories
        let protDiff = proteinTarget - totalProtein

        if filledCount == 3 && abs(calDiff) < 200 && abs(protDiff) < 20 {
            return ("hand.thumbsup.fill", "Balanced day — looking great!", [], .green)
        }
        if protDiff > 30 {
            return ("bolt.fill", "You're \(protDiff)g under your protein goal", [], .cyan)
        }
        if calDiff < -200 {
            return ("exclamationmark.triangle.fill", "Over calorie target by \(abs(calDiff)) kcal", [], .red)
        }
        if totalCost > budgetTarget {
            return ("banknote.fill", "Over budget by \(String(format: "%.0f", totalCost - budgetTarget)) \(currency) — try cheaper options", [], .red)
        }
        if filledCount < 3 {
            return ("fork.knife", "\(3 - filledCount) meal\(filledCount == 2 ? "" : "s") still empty", [], .secondary)
        }
        return ("checkmark.seal.fill", "On track for today's goals", [], .green)
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
            let isToday = calendar.isDateInToday(date)
            return MealPlanDay(
                date: date,
                meals: Meal.MealType.allCases.map { type in
                    Meal(type: type, recipe: (isToday && type == .lunch) ? Recipe.samples.first : nil)
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
        for i in weekDays[selectedDayIndex].meals.indices where weekDays[selectedDayIndex].meals[i].recipe == nil {
            weekDays[selectedDayIndex].meals[i].recipe = Recipe.samples.randomElement()
        }
    }

    func generateDay() {
        isGenerating = true
        revealedMealIndex = -1
        let idx = selectedDayIndex
        guard weekDays.indices.contains(idx) else { return }

        // Staggered reveal: each meal appears one by one
        for i in weekDays[idx].meals.indices {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8 + Double(i) * 0.4) { [weak self] in
                guard let self, self.weekDays.indices.contains(idx) else { return }
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    self.weekDays[idx].meals[i].recipe = Recipe.samples.randomElement()
                    self.revealedMealIndex = i
                }
                // After last meal → finish
                if i == self.weekDays[idx].meals.count - 1 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        withAnimation(.snappy(duration: 0.4)) {
                            self.isGenerating = false
                            self.showSuccessBanner = true
                        }
                        // Auto-hide banner
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                            withAnimation(.easeOut(duration: 0.3)) {
                                self.showSuccessBanner = false
                            }
                        }
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self else { return }
            withAnimation(.snappy(duration: 0.5)) {
                let balanced = Recipe.samples.sorted { abs($0.protein - 40) < abs($1.protein - 40) }
                for i in self.weekDays[self.selectedDayIndex].meals.indices {
                    let pick = balanced[i % balanced.count]
                    self.weekDays[self.selectedDayIndex].meals[i].recipe = pick
                }
                self.isOptimizing = false
                self.showSuccessBanner = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation(.easeOut(duration: 0.3)) {
                    self.showSuccessBanner = false
                }
            }
        }
    }

    func replaceWithRandom(at index: Int) {
        guard weekDays.indices.contains(selectedDayIndex),
              weekDays[selectedDayIndex].meals.indices.contains(index) else { return }

        weekDays[selectedDayIndex].meals[index].recipe = Recipe.samples.randomElement()
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

    // MARK: - Month view

    /// All days visible in the month grid — padded with leading/trailing days
    /// from adjacent months so the grid always starts on the locale's first
    /// weekday and fills complete rows (iOS 26 Calendar-app style).
    var monthGridDays: [Date] {
        let cal = calendar
        guard let interval = cal.dateInterval(of: .month, for: visibleMonth) else { return [] }
        let firstOfMonth = interval.start
        // Start the grid on the first day of the week containing firstOfMonth.
        let weekdayOfFirst = cal.component(.weekday, from: firstOfMonth)
        let firstWeekday = cal.firstWeekday
        let leadingOffset = (weekdayOfFirst - firstWeekday + 7) % 7
        guard let gridStart = cal.date(byAdding: .day, value: -leadingOffset, to: firstOfMonth) else { return [] }

        // 6 rows × 7 cols = 42 cells — covers every possible month layout.
        return (0..<42).compactMap { cal.date(byAdding: .day, value: $0, to: gridStart) }
    }

    var monthTitle: String {
        let f = DateFormatter()
        f.locale = Locale.current
        f.dateFormat = "LLLL yyyy"
        return f.string(from: visibleMonth).capitalized(with: .current)
    }

    var weekdaySymbols: [String] {
        let cal = calendar
        let f = DateFormatter()
        f.locale = Locale.current
        let rotated = Array(f.veryShortStandaloneWeekdaySymbols.dropFirst(cal.firstWeekday - 1))
                    + Array(f.veryShortStandaloneWeekdaySymbols.prefix(cal.firstWeekday - 1))
        return rotated
    }

    func isInVisibleMonth(_ date: Date) -> Bool {
        calendar.isDate(date, equalTo: visibleMonth, toGranularity: .month)
    }

    /// Lookup a cached meal plan for a specific date.
    func plan(on date: Date) -> MealPlanDay? {
        let key = calendar.startOfDay(for: date)
        if let cached = monthPlans[key] { return cached }
        // Fall back to the currently-loaded week
        return weekDays.first { calendar.isDate($0.date, inSameDayAs: date) }
    }

    func stepMonth(by value: Int) {
        guard let next = calendar.date(byAdding: .month, value: value, to: visibleMonth) else { return }
        withAnimation(.snappy(duration: 0.3)) { visibleMonth = next }
        Task { await loadVisibleMonth() }
    }

    func selectDate(_ date: Date) {
        // If the date falls inside the current week, just update the index;
        // otherwise rebuild the week anchored on the selected date.
        if let idx = weekDays.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: date) }) {
            selectDay(idx)
        } else {
            anchorWeek(on: date)
        }
        withAnimation(.snappy(duration: 0.3)) { mode = .day }
    }

    private func anchorWeek(on date: Date) {
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)) ?? date
        weekDays = (0..<7).compactMap { offset in
            guard let d = calendar.date(byAdding: .day, value: offset, to: startOfWeek) else { return nil }
            let existing = monthPlans[calendar.startOfDay(for: d)]
            return existing ?? MealPlanDay(
                date: d,
                meals: Meal.MealType.allCases.map { Meal(type: $0, recipe: nil) }
            )
        }
        selectedDayIndex = weekDays.firstIndex { calendar.isDate($0.date, inSameDayAs: date) } ?? 0
    }

    // MARK: - Backend loading

    private static let apiDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .iso8601)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// Load all plans that fall inside the currently visible month (+
    /// 6-day overflow on both sides so the grid cells for adjacent months
    /// also display meal dots).
    @MainActor
    func loadVisibleMonth() async {
        guard let interval = calendar.dateInterval(of: .month, for: visibleMonth) else { return }
        let from = calendar.date(byAdding: .day, value: -7, to: interval.start) ?? interval.start
        let to   = calendar.date(byAdding: .day, value: 7, to: interval.end) ?? interval.end
        await loadRange(from: from, to: to)
    }

    @MainActor
    func loadRange(from: Date, to: Date) async {
        isLoadingMonth = true
        defer { isLoadingMonth = false }

        let fromStr = Self.apiDateFormatter.string(from: from)
        let toStr   = Self.apiDateFormatter.string(from: to)
        do {
            let days = try await APIClient.shared.getMealPlanRange(from: fromStr, to: toStr)
            var dict: [Date: MealPlanDay] = monthPlans
            for dto in days {
                guard let d = Self.apiDateFormatter.date(from: dto.date) else { continue }
                let key = calendar.startOfDay(for: d)
                let meals: [Meal] = Meal.MealType.allCases.map { type in
                    let slot = type.rawValue.lowercased()
                    let entry = dto.meals.first { $0.slot.lowercased() == slot }
                    if let rec = entry?.recipe {
                        // Best-effort mapping — fallback sample if lookup fails
                        let sample = Recipe.samples.first { $0.title == rec.title } ?? Recipe.samples.first
                        return Meal(type: type, recipe: sample)
                    }
                    return Meal(type: type, recipe: nil)
                }
                dict[key] = MealPlanDay(date: d, meals: meals)
            }
            monthPlans = dict
        } catch {
            // Backend not ready or offline — keep local sample data.
            #if DEBUG
            print("[Plan] loadRange failed: \(error.localizedDescription)")
            #endif
        }
    }
}
