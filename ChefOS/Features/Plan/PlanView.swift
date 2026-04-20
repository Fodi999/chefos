//
//  PlanView.swift
//  ChefOS
//

import SwiftUI

// MARK: - Features/Plan

struct PlanView: View {
    @EnvironmentObject var viewModel: PlanViewModel
    @EnvironmentObject var regionService: RegionService
    @EnvironmentObject var usageService: UsageService
    @EnvironmentObject var l10n: LocalizationService
    @State private var appeared = false
    @State private var smartPlanBreathing = false
    @State private var expandedMealId: UUID? = nil
    @StateObject private var favVM = FavoritesViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient.screenBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // MARK: Day | Week toggle
                        viewToggle
                            .staggerIn(appeared: appeared, delay: 0)

                        // MARK: Calendar Strip
                        calendarStrip
                            .staggerIn(appeared: appeared, delay: 0.03)

                        if viewModel.showWeekView {
                            weekOverview
                                .staggerIn(appeared: appeared, delay: 0.06)
                        } else {
                            // MARK: Usage
                            UsageBanner(
                                icon: "sparkles",
                                text: l10n.t("plan.generationsLeft"),
                                remaining: usageService.plansRemaining,
                                total: UsageService.DailyLimits.plans,
                                color: .orange
                            )
                            .staggerIn(appeared: appeared, delay: 0.05)

                            // MARK: Soft warning banner
                            if !usageService.actionCostPreview.isEmpty {
                                HStack(spacing: 6) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.caption2)
                                        .foregroundStyle(.yellow)
                                    Text(usageService.actionCostPreview)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.yellow)
                                    Spacer()
                                    Text("\(l10n.t("plan.resetsIn")) \(usageService.timeUntilReset)")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color.yellow.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .transition(.move(edge: .top).combined(with: .opacity))
                            }

                            // MARK: Value moment — savings
                            if viewModel.totalCost > 0 && viewModel.budgetTarget > 0 {
                                let saved = viewModel.budgetTarget - viewModel.totalCost
                                if saved > 0 {
                                    HStack(spacing: 6) {
                                        Image(systemName: "leaf.fill")
                                            .font(.caption2)
                                            .foregroundStyle(.green)
                                        Text("\(l10n.t("plan.saves")) \(Int(saved)) \(regionService.currency) \(l10n.t("plan.today"))")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.green)
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }
                            }

                            // MARK: Smart suggestion — over budget
                            if viewModel.totalCost > viewModel.budgetTarget && viewModel.budgetTarget > 0 && usageService.canOptimize() {
                                Button {
                                    usageService.requestAction("optimization", canPerform: usageService.canOptimize()) {
                                        usageService.useOptimize()
                                        viewModel.optimizeDay()
                                    }
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: "exclamationmark.circle.fill")
                                            .foregroundStyle(.orange)
                                        Text(l10n.t("plan.overBudget"))
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(.orange)
                                        Spacer()
                                        Image(systemName: "wand.and.stars")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }
                                .buttonStyle(PressButtonStyle())
                            }

                            // MARK: Smart Plan + Optimize
                            HStack(spacing: 10) {
                                smartPlanButton
                                optimizeButton
                            }
                            .staggerIn(appeared: appeared, delay: 0.06)

                            // MARK: Daily Stats with targets
                            dailyStats
                                .staggerIn(appeared: appeared, delay: 0.09)

                            // MARK: AI Insight
                            insightCard
                                .staggerIn(appeared: appeared, delay: 0.12)

                            // MARK: Meals
                            VStack(spacing: 14) {
                                ForEach(Array(viewModel.selectedDay.meals.enumerated()), id: \.element.id) { index, meal in
                                    MealRow(
                                        meal: meal,
                                        isLoading: viewModel.isGenerating || viewModel.isOptimizing,
                                        isExpanded: expandedMealId == meal.id,
                                        currency: regionService.currency,
                                        favVM: favVM,
                                        onAdd: {
                                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                                viewModel.replaceWithRandom(at: index)
                                            }
                                        },
                                        onClear: {
                                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                                viewModel.clearMeal(at: index)
                                                if expandedMealId == meal.id { expandedMealId = nil }
                                            }
                                        },
                                        onTap: {
                                            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                                                expandedMealId = (expandedMealId == meal.id) ? nil : meal.id
                                            }
                                        }
                                    )
                                    .staggerIn(appeared: appeared, delay: 0.15 + Double(index) * 0.05)
                                }
                            }

                            // MARK: Day Shopping Summary
                            dayShoppingSummary
                                .staggerIn(appeared: appeared, delay: 0.3)
                        }
                    }
                    .padding()
                    .padding(.bottom, 80)
                }
            }
            .navigationTitle(l10n.t("plan.title"))
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        withAnimation(.snappy(duration: 0.4)) {
                            viewModel.clearDay()
                        }
                    } label: {
                        Image(systemName: "trash")
                            .font(.subheadline)
                            .foregroundStyle(.secondary.opacity(0.4))
                    }
                    .buttonStyle(PressButtonStyle())
                }
            }
            .onAppear {
                withAnimation(.easeOut(duration: 0.5)) {
                    appeared = true
                }
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    smartPlanBreathing = true
                }
            }
            .overlay(alignment: .top) {
                if viewModel.showSuccessBanner {
                    successBanner
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .padding(.top, 8)
                }
                if viewModel.showAddedToPlanBanner {
                    addedToPlanBanner
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .padding(.top, 8)
                }
            }
            .sheet(isPresented: $usageService.showPaywall) {
                PaywallView()
            }
        }
    }

    // MARK: - Success Banner

    private var successBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.body.weight(.semibold))
                .foregroundStyle(.green)
            Text(l10n.t("plan.planReady"))
                .font(.subheadline.weight(.bold))
            Text(l10n.t("plan.optimizedGoals"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(
            Capsule()
                .strokeBorder(Color.green.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .green.opacity(0.2), radius: 12, y: 4)
    }

    // MARK: - Added to Plan Banner

    private var addedToPlanBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "calendar.badge.plus")
                .font(.body.weight(.semibold))
                .foregroundStyle(.cyan)
            Text("\(l10n.t("plan.addedTo")) \(viewModel.addedToPlanSlot)")
                .font(.subheadline.weight(.bold))
            Text("— \(viewModel.addedToPlanTitle)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(
            Capsule()
                .strokeBorder(Color.cyan.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .cyan.opacity(0.2), radius: 12, y: 4)
    }

    // MARK: - View Toggle (Premium)

    private var viewToggle: some View {
        HStack(spacing: 0) {
            ForEach([("Day", l10n.t("plan.day")), ("Week", l10n.t("plan.week"))], id: \.0) { mode, label in
                let isActive = (mode == "Day" && !viewModel.showWeekView) || (mode == "Week" && viewModel.showWeekView)
                Button {
                    withAnimation(.snappy(duration: 0.35)) {
                        viewModel.showWeekView = (mode == "Week")
                    }
                } label: {
                    Text(label)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isActive ? .white : .white.opacity(0.4))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 9)
                        .background {
                            if isActive {
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [.orange, Color(red: 0.9, green: 0.4, blue: 0.1)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .shadow(color: .orange.opacity(0.3), radius: 10, y: 3)
                            }
                        }
                        .animation(.snappy(duration: 0.3), value: isActive)
                }
                .buttonStyle(PressButtonStyle())
            }
        }
        .padding(3)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .frame(maxWidth: .infinity, alignment: .center)
    }

    // MARK: - Day Shopping Summary

    @ViewBuilder
    private var dayShoppingSummary: some View {
        let allMissing = viewModel.selectedDay.meals
            .compactMap { $0.recipe }
            .flatMap { $0.recipeIngredients.filter { !$0.available } }

        if !allMissing.isEmpty {
            // Deduplicate by name, sum quantities
            let grouped = Dictionary(grouping: allMissing, by: \.name)
            let items = grouped.map { (name: $0.key, totalG: $0.value.reduce(0) { $0 + $1.quantity }) }
                .sorted { $0.name < $1.name }

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "cart.fill")
                        .foregroundStyle(.red)
                    Text(l10n.t("plan.shoppingList"))
                        .font(.headline.weight(.bold))
                    Spacer()
                    Text("\(items.count)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.red.opacity(0.7), in: Capsule())
                }

                ForEach(items, id: \.name) { item in
                    HStack(spacing: 8) {
                        Image(systemName: "circle")
                            .font(.caption2)
                            .foregroundStyle(.red.opacity(0.6))
                        Text(item.name)
                            .font(.subheadline)
                        Spacer()
                        Text("\(Int(item.totalG))g")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.red.opacity(0.3), lineWidth: 1)
            )
        }
    }

    // MARK: - Smart Plan Button (Hero)

    @State private var smartPlanGlow = false
    @State private var shimmerOffset: CGFloat = -200

    private var smartPlanButton: some View {
        Button {
            usageService.requestAction("plan generation", canPerform: usageService.canGeneratePlan()) {
                usageService.useGeneratePlan()
                viewModel.generateDay()
            }
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    if viewModel.isGenerating {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    } else {
                        Image(systemName: "sparkles")
                            .font(.title3.weight(.semibold))
                            .symbolEffect(.bounce, options: .repeating.speed(0.3), isActive: smartPlanGlow)
                    }
                }
                .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.isGenerating ? l10n.t("plan.generating") : l10n.t("plan.smartPlan"))
                        .font(.headline.weight(.bold))
                    Text(viewModel.isGenerating ? l10n.t("plan.aiThinking") : l10n.t("plan.generateAll"))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }

                Spacer()
            }
            .foregroundStyle(.white)
            .padding(16)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.orange, Color(red: 0.95, green: 0.45, blue: 0.1), Color(red: 0.85, green: 0.3, blue: 0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        // Inner light
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [.white.opacity(0.18), .clear],
                                    startPoint: .top,
                                    endPoint: .center
                                )
                            )
                    }
                    .overlay {
                        // Traveling shimmer
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [.clear, .white.opacity(0.12), .clear],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .offset(x: shimmerOffset)
                            .mask(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
            }
            .shadow(color: .orange.opacity(smartPlanBreathing ? 0.45 : 0.2), radius: smartPlanBreathing ? 24 : 12, y: 6)
            .scaleEffect(smartPlanBreathing ? 1.01 : 0.99)
        }
        .buttonStyle(PressButtonStyle())
        .disabled(viewModel.isGenerating)
        .opacity(viewModel.isGenerating ? 0.85 : 1)
        .animation(.easeInOut(duration: 0.3), value: viewModel.isGenerating)
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                smartPlanGlow = true
            }
            withAnimation(.linear(duration: 2.5).repeatForever(autoreverses: false)) {
                shimmerOffset = 400
            }
        }
    }

    // MARK: - Optimize Button (Secondary)

    private var optimizeButton: some View {
        Button {
            usageService.requestAction("optimization", canPerform: usageService.canOptimize()) {
                usageService.useOptimize()
                viewModel.optimizeDay()
            }
        } label: {
            VStack(spacing: 5) {
                ZStack {
                    if viewModel.isOptimizing {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.cyan)
                    } else {
                        Image(systemName: "wand.and.stars")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(
                                LinearGradient(colors: [.cyan, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                    }
                }
                .frame(width: 22, height: 22)

                Text(l10n.t("plan.optimize"))
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 72)
            .padding(.vertical, 14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(PressButtonStyle())
        .disabled(viewModel.isOptimizing || viewModel.filledCount == 0)
        .opacity(viewModel.filledCount == 0 ? 0.4 : 1)
    }

    // MARK: - Calendar Strip

    private var calendarStrip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(viewModel.weekDays.enumerated()), id: \.element.id) { index, day in
                        CalendarDayCell(
                            dayLetter: viewModel.dayLetter(for: day.date),
                            dayNumber: viewModel.dayNumber(for: day.date),
                            isSelected: index == viewModel.selectedDayIndex,
                            isToday: viewModel.isToday(day.date),
                            hasMeals: day.meals.contains { $0.recipe != nil }
                        )
                        .id(index)
                        .onTapGesture {
                            viewModel.selectDay(index)
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
            .padding(.vertical, 4)
            .glassCard(cornerRadius: 20)
            .onAppear {
                proxy.scrollTo(viewModel.selectedDayIndex, anchor: .center)
            }
        }
    }

    // MARK: - Daily Stats with Targets

    private var dailyStats: some View {
        VStack(spacing: 14) {
            HStack(spacing: 16) {
                ProgressRing(
                    progress: viewModel.calorieProgress,
                    icon: "flame.fill",
                    current: viewModel.totalCalories,
                    target: viewModel.calorieTarget,
                    unit: l10n.t("plan.kcal"),
                    color: .orange
                )

                ProgressRing(
                    progress: viewModel.proteinProgress,
                    icon: "bolt.fill",
                    current: viewModel.totalProtein,
                    target: viewModel.proteinTarget,
                    unit: l10n.t("plan.gProtein"),
                    color: .cyan
                )

                CostRing(
                    progress: viewModel.costProgress,
                    current: viewModel.totalCost,
                    target: viewModel.budgetTarget,
                    color: viewModel.totalCost > viewModel.budgetTarget ? .red : .green,
                    currency: regionService.currency
                )
            }

            // Budget status
            let status = viewModel.budgetStatus
            HStack(spacing: 6) {
                Text(localizeWithArgs(status.key, args: status.args))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(status.color)
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 18)
    }

    // MARK: - AI Insight

    private var insightCard: some View {
        let insight = viewModel.insight
        return HStack(spacing: 10) {
            Image(systemName: insight.icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(insight.color)
                .frame(width: 32, height: 32)
                .background(insight.color.opacity(0.12), in: Circle())

            Text(localizeWithArgs(insight.key, args: insight.args))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary.opacity(0.9))

            Spacer()
        }
        .padding(14)
        .glassCard(cornerRadius: 16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(insight.color.opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - Week Overview (Premium)

    private var weekOverview: some View {
        VStack(spacing: 14) {
            // Week progress header
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(l10n.t("plan.weekOverview"))
                            .font(.headline)
                        Text("\(viewModel.weekFilledMeals) of 21 \(l10n.t("plan.meals")) · \(viewModel.weekCalories) kcal")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    HStack(spacing: 2) {
                        Text("\(viewModel.weekDaysCompleted)/7")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.orange)
                        Text(l10n.t("plan.days"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Week progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.06))
                        Capsule()
                            .fill(LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * CGFloat(viewModel.weekDaysCompleted) / 7.0)
                            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: viewModel.weekDaysCompleted)
                    }
                }
                .frame(height: 8)
                .clipShape(Capsule())
            }
            .padding(16)
            .glassCard(cornerRadius: 18)

            // Day rows
            ForEach(Array(viewModel.weekDays.enumerated()), id: \.element.id) { index, day in
                let filled = viewModel.dayFilledCount(for: day)
                let cals = viewModel.dayCalories(for: day)
                let mealIcons = viewModel.mealIcons(for: day)

                Button {
                    withAnimation(.snappy(duration: 0.35)) {
                        viewModel.showWeekView = false
                        viewModel.selectedDayIndex = index
                    }
                } label: {
                    HStack(spacing: 12) {
                        // Day badge
                        VStack(spacing: 2) {
                            Text(viewModel.dayLetter(for: day.date))
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(viewModel.isToday(day.date) ? .orange : .secondary)
                            Text(viewModel.dayNumber(for: day.date))
                                .font(.headline.weight(.bold))
                        }
                        .frame(width: 38)

                        if filled == 0 {
                            // Empty state — conversational
                            VStack(alignment: .leading, spacing: 3) {
                                Text(l10n.t("plan.noMeals"))
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.secondary)
                                Text(l10n.t("plan.tapGenerate"))
                                    .font(.caption2)
                                    .foregroundStyle(.orange.opacity(0.8))
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 5) {
                                // Meal icon preview
                                HStack(spacing: 6) {
                                    ForEach(Array(mealIcons.enumerated()), id: \.offset) { _, icon in
                                        Image(systemName: icon.symbol)
                                            .font(.subheadline)
                                            .foregroundStyle(icon.filled ? .orange : .secondary.opacity(0.4))
                                    }
                                    Spacer()
                                    Text("\(cals) kcal")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.orange)
                                    let dayCostVal = viewModel.dayCost(for: day)
                                    if dayCostVal > 0 {
                                        Text(String(format: "%.0f %@", dayCostVal, regionService.currency))
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.green)
                                    }
                                }

                                // Mini progress
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        Capsule()
                                            .fill(Color.white.opacity(0.06))
                                        Capsule()
                                            .fill(
                                                cals > viewModel.calorieTarget
                                                    ? LinearGradient(colors: [.red, .orange], startPoint: .leading, endPoint: .trailing)
                                                    : LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing)
                                            )
                                            .frame(width: geo.size.width * min(CGFloat(cals) / CGFloat(max(viewModel.calorieTarget, 1)), 1.0))
                                    }
                                }
                                .frame(height: 4)
                                .clipShape(Capsule())
                            }
                        }

                        Spacer(minLength: 0)

                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary.opacity(0.4))
                    }
                    .padding(14)
                    .glassCard(cornerRadius: 16)
                    .overlay {
                        if viewModel.isToday(day.date) {
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(Color.orange.opacity(0.25), lineWidth: 1)
                        }
                    }
                }
                .buttonStyle(PressButtonStyle())
            }
        }
    }

    private func localizeWithArgs(_ key: String, args: [String]) -> String {
        var result = l10n.t(key)
        for arg in args {
            if let range = result.range(of: "%@") {
                result.replaceSubrange(range, with: arg)
            }
        }
        return result
    }
}

// MARK: - ProgressRing

struct ProgressRing: View {
    let progress: Double
    let icon: String
    let current: Int
    let target: Int
    let unit: String
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.12), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
                Image(systemName: icon)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(color)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 3) {
                    Text(current >= 1000 ? String(format: "%,d", current).replacingOccurrences(of: ",", with: " ") : "\(current)")
                        .font(.subheadline.weight(.bold))
                    Text("/ \(target >= 1000 ? String(format: "%,d", target).replacingOccurrences(of: ",", with: " ") : "\(target)")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(unit)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - CostRing

struct CostRing: View {
    let progress: Double
    let current: Double
    let target: Double
    let color: Color
    var currency: String = "$"

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.12), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: min(progress, 1.0))
                    .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
                Image(systemName: "banknote.fill")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(color)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 3) {
                    Text(String(format: "%.0f", current))
                        .font(.subheadline.weight(.bold))
                    Text("/ \(String(format: "%.0f", target))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(currency)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - CalendarDayCell

struct CalendarDayCell: View {
    let dayLetter: String
    let dayNumber: String
    let isSelected: Bool
    let isToday: Bool
    let hasMeals: Bool

    var body: some View {
        VStack(spacing: 6) {
            Text(dayLetter)
                .font(.caption2.weight(.medium))
                .foregroundStyle(isSelected ? .white : .secondary)

            Text(dayNumber)
                .font(.title3.weight(.bold))
                .foregroundStyle(isSelected ? .white : .primary)

            Circle()
                .fill(hasMeals ? .orange : .clear)
                .frame(width: 5, height: 5)
        }
        .frame(width: 48, height: 72)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 14)
                    .fill(LinearGradient.userBubble)
                    .shadow(color: .orange.opacity(0.2), radius: 8, y: 2)
            } else if isToday {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color.orange.opacity(0.4), lineWidth: 1)
            }
        }
        .contentShape(Rectangle())
    }
}

// MARK: - MealRow

struct MealRow: View {
    let meal: Meal
    let isLoading: Bool
    var isExpanded: Bool = false
    var currency: String = "$"
    @ObservedObject var favVM: FavoritesViewModel
    var onAdd: () -> Void
    var onClear: () -> Void
    var onTap: () -> Void
    @EnvironmentObject var l10n: LocalizationService

    private var localizedMealType: String {
        switch meal.type {
        case .breakfast: return l10n.t("plan.breakfast")
        case .lunch: return l10n.t("plan.lunch")
        case .dinner: return l10n.t("plan.dinner")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // MARK: Header
            HStack {
                Image(systemName: iconName)
                    .font(meal.type == .lunch ? .title2 : .title3)
                    .foregroundStyle(iconGradient)
                    .frame(width: meal.type == .lunch ? 40 : 36, height: meal.type == .lunch ? 40 : 36)
                    .background(iconColor.opacity(meal.type == .lunch ? 0.2 : 0.12), in: RoundedRectangle(cornerRadius: meal.type == .lunch ? 12 : 10))

                VStack(alignment: .leading, spacing: 1) {
                    Text(localizedMealType)
                        .font(meal.type == .lunch ? .headline.weight(.bold) : .subheadline.weight(.semibold))
                    if meal.type == .lunch && meal.recipe != nil {
                        Text(l10n.t("plan.mainMeal"))
                            .font(.caption2)
                            .foregroundStyle(.orange.opacity(0.8))
                    }
                }

                Spacer()

                if let recipe = meal.recipe {
                    // Favorite button
                    if let dish = recipe.sourceDish {
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                favVM.toggle(dish)
                            }
                        } label: {
                            Image(systemName: favVM.isFavorite(dish.dishName) ? "heart.fill" : "heart")
                                .font(.body)
                                .foregroundStyle(favVM.isFavorite(dish.dishName) ? .red : .secondary.opacity(0.5))
                                .symbolEffect(.bounce, value: favVM.isFavorite(dish.dishName))
                        }
                        .buttonStyle(.plain)
                    }

                    HStack(spacing: 6) {
                        Text("\(recipe.calories) kcal")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.orange.opacity(0.12), in: Capsule())
                        if recipe.estimatedCost > 0 {
                            Text(String(format: "%.2f %@", recipe.estimatedCost, currency))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.green)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.green.opacity(0.12), in: Capsule())
                        }
                        if !recipe.recipeIngredients.filter({ !$0.available }).isEmpty {
                            Image(systemName: "cart.badge.plus")
                                .font(.caption2)
                                .foregroundStyle(.red)
                                .padding(4)
                                .background(.red.opacity(0.12), in: Circle())
                        }
                    }
                }
            }

            if let recipe = meal.recipe {
                Divider().overlay(Color.white.opacity(0.06))

                // MARK: Collapsed summary
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(recipe.title)
                            .font(.subheadline.weight(.medium))

                        if !recipe.dishType.isEmpty {
                            HStack(spacing: 6) {
                                Text(recipe.dishType)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.cyan)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.cyan.opacity(0.1), in: Capsule())
                                if !recipe.complexity.isEmpty {
                                    Text(recipe.complexity)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        } else {
                            Text(recipe.ingredients.prefix(3).joined(separator: " · "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                    HStack(spacing: 8) {
                        Button { onAdd() } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.caption2.weight(.bold))
                                Text(l10n.t("plan.replace"))
                                    .font(.caption2.weight(.semibold))
                            }
                        }
                        .buttonStyle(.bordered)
                        .tint(.orange)
                        .controlSize(.small)

                        Button { onClear() } label: {
                            Image(systemName: "xmark")
                                .font(.caption2.weight(.medium))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary.opacity(0.35))
                    }
                }

                // Tap hint
                if !isExpanded {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                        Text(l10n.t("plan.tapToExpand"))
                            .font(.caption2)
                    }
                    .foregroundStyle(.secondary.opacity(0.5))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 2)
                }

                // MARK: Expanded Detail
                if isExpanded {
                    expandedDetail(recipe: recipe)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            } else {
                Button(action: onAdd) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                        Text(l10n.t("plan.addMeal"))
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.orange.opacity(0.9))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(.orange.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .padding(meal.type == .lunch ? 18 : 14)
        .glassCard(cornerRadius: 18)
        .shadow(color: .black.opacity(0.25), radius: 10, y: 5)
        .opacity(meal.type == .dinner ? 0.85 : 1.0)
        .overlay {
            if meal.type == .lunch {
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(
                        LinearGradient(colors: [.orange.opacity(0.2), .yellow.opacity(0.1), .clear], startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 1
                    )
            }
            if isExpanded {
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(Color.orange.opacity(0.15), lineWidth: 1)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if meal.recipe != nil { onTap() }
        }
        .redacted(reason: isLoading ? .placeholder : [])
        .opacity(isLoading ? 0.45 : 1)
        .animation(.easeInOut(duration: 0.4), value: isLoading)
        .if(isLoading) { view in view.shimmering() }
        .transition(.asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .opacity
        ))
    }

    // MARK: - Expanded Detail

    @ViewBuilder
    private func expandedDetail(recipe: Recipe) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Divider().overlay(Color.white.opacity(0.06))

            // Nutrition row
            HStack(spacing: 12) {
                nutriPill(icon: "flame.fill", value: "\(recipe.calories)", unit: l10n.t("plan.kcal"), color: .orange)
                nutriPill(icon: "bolt.fill", value: "\(recipe.protein)", unit: l10n.t("plan.gP"), color: .cyan)
                nutriPill(icon: "drop.fill", value: "\(recipe.fat)", unit: l10n.t("plan.gF"), color: .yellow)
                nutriPill(icon: "leaf.fill", value: "\(recipe.carbs)", unit: l10n.t("plan.gC"), color: .green)
            }

            // Tags
            if !recipe.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(recipe.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.purple)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(.purple.opacity(0.1), in: Capsule())
                        }
                    }
                }
            }

            // Ingredients
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "basket.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                    Text(l10n.t("plan.ingredients"))
                        .font(.subheadline.weight(.bold))
                    Spacer()
                    Text("\(recipe.recipeIngredients.count)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                ForEach(recipe.recipeIngredients) { ing in
                    HStack(spacing: 8) {
                        Image(systemName: ing.available ? "checkmark.circle.fill" : "circle.dashed")
                            .font(.caption)
                            .foregroundStyle(ing.available ? .green : .red.opacity(0.7))
                        Text(ing.name)
                            .font(.caption)
                            .foregroundStyle(ing.available ? .primary : .secondary)
                        Spacer()
                        Text("\(Int(ing.quantity))g")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                        if !ing.role.isEmpty {
                            Text(ing.role)
                                .font(.caption2)
                                .foregroundStyle(.cyan.opacity(0.7))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(.cyan.opacity(0.08), in: Capsule())
                        }
                    }
                }
            }
            .padding(12)
            .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 12))

            // Missing ingredients — need to buy
            let missing = recipe.recipeIngredients.filter { !$0.available }
            if !missing.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "cart.badge.plus")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.red)
                        Text(l10n.t("plan.needToBuy"))
                            .font(.subheadline.weight(.bold))
                        Spacer()
                        Text("\(missing.count)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Color.red.opacity(0.7), in: Capsule())
                    }

                    ForEach(missing) { ing in
                        HStack(spacing: 8) {
                            Image(systemName: "circle.dashed")
                                .font(.caption)
                                .foregroundStyle(.red.opacity(0.7))
                            Text(ing.name)
                                .font(.caption)
                            Spacer()
                            Text("\(Int(ing.quantity))g")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(12)
                .background(Color.red.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.red.opacity(0.2), lineWidth: 1)
                )
            }

            // Steps
            if !recipe.richSteps.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "list.number")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.orange)
                        Text(l10n.t("plan.steps"))
                            .font(.subheadline.weight(.bold))
                        Spacer()
                        Text("\(recipe.richSteps.count) \(l10n.t("plan.stepsCount"))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    ForEach(recipe.richSteps) { step in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(alignment: .top, spacing: 8) {
                                Text("\(step.id)")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.orange)
                                    .frame(width: 20, height: 20)
                                    .background(.orange.opacity(0.12), in: Circle())

                                Text(step.text)
                                    .font(.caption)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            HStack(spacing: 8) {
                                if let time = step.timeMin {
                                    Label("\(time) min", systemImage: "clock")
                                        .font(.caption2.weight(.medium))
                                        .foregroundStyle(.cyan)
                                }
                                if let temp = step.tempC {
                                    Label("\(temp)°C", systemImage: "thermometer.medium")
                                        .font(.caption2.weight(.medium))
                                        .foregroundStyle(.red)
                                }
                            }
                            .padding(.leading, 28)

                            if let tip = step.tip, !tip.isEmpty {
                                HStack(spacing: 4) {
                                    Image(systemName: "lightbulb.fill")
                                        .font(.caption2)
                                        .foregroundStyle(.yellow)
                                    Text(tip)
                                        .font(.caption2)
                                        .foregroundStyle(.yellow.opacity(0.8))
                                }
                                .padding(.leading, 28)
                                .padding(.vertical, 2)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
                .padding(12)
                .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 12))
            }

            // Warnings
            if !recipe.warnings.isEmpty {
                ForEach(recipe.warnings, id: \.self) { w in
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                        Text(w)
                            .font(.caption2)
                            .foregroundStyle(.yellow.opacity(0.8))
                    }
                }
            }

            // Collapse hint
            HStack {
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "chevron.up")
                        .font(.caption2)
                    Text(l10n.t("plan.tapToCollapse"))
                        .font(.caption2)
                }
                .foregroundStyle(.secondary.opacity(0.5))
                Spacer()
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Nutrition Pill

    private func nutriPill(icon: String, value: String, unit: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(color)
            Text(value)
                .font(.caption.weight(.bold))
            Text(unit)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Localize with args helper

    private func localizeWithArgs(_ key: String, args: [String]) -> String {
        var result = l10n.t(key)
        for arg in args {
            if let range = result.range(of: "%@") {
                result.replaceSubrange(range, with: arg)
            }
        }
        return result
    }

    private var iconName: String {
        switch meal.type {
        case .breakfast: return "sunrise.fill"
        case .lunch: return "sun.max.fill"
        case .dinner: return "moon.stars.fill"
        }
    }

    private var iconColor: Color {
        switch meal.type {
        case .breakfast: return .orange
        case .lunch: return .yellow
        case .dinner: return .indigo
        }
    }

    private var iconGradient: LinearGradient {
        switch meal.type {
        case .breakfast: return LinearGradient(colors: [.orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .lunch: return LinearGradient(colors: [.yellow, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .dinner: return LinearGradient(colors: [.indigo, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

// MARK: - Shimmer Modifier

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [.clear, .white.opacity(0.08), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .offset(x: phase)
                .mask(content)
            )
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 400
                }
            }
    }
}

extension View {
    func shimmering() -> some View {
        modifier(ShimmerModifier())
    }

    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

#Preview {
    PlanView()
        .environmentObject(PlanViewModel())
        .environmentObject(RegionService())
        .environmentObject(UsageService())
        .environmentObject(LocalizationService())
}
