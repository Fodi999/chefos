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
    @State private var expandedMealId: UUID? = nil
    @StateObject private var favVM = FavoritesViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // MARK: Day | Week toggle
                        PlanHeader(
                            showingWeek: viewModel.showWeekView,
                            dayLabel: l10n.t("plan.day"),
                            weekLabel: l10n.t("plan.week"),
                            onSelect: { viewModel.showWeekView = $0 }
                        )
                        .staggerIn(appeared: appeared, delay: 0)

                        // MARK: Calendar Strip
                        DaySelector(
                            days: viewModel.weekDays.enumerated().map { index, day in
                                DayCellModel(
                                    id: index,
                                    dayLetter: viewModel.dayLetter(for: day.date),
                                    dayNumber: viewModel.dayNumber(for: day.date),
                                    isSelected: index == viewModel.selectedDayIndex,
                                    isToday: viewModel.isToday(day.date),
                                    hasMeals: day.meals.contains { $0.recipe != nil }
                                )
                            },
                            onSelect: { viewModel.selectDay($0) }
                        )
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

                            // MARK: Status Group — warnings / savings merged into one card
                            let hasCostPreview = !usageService.actionCostPreview.isEmpty
                            let saved = viewModel.budgetTarget - viewModel.totalCost
                            let hasSavings = viewModel.totalCost > 0 && viewModel.budgetTarget > 0 && saved > 0
                            let isOverBudget = viewModel.totalCost > viewModel.budgetTarget && viewModel.budgetTarget > 0

                            if hasCostPreview || hasSavings || isOverBudget {
                                GroupCard {
                                    if hasCostPreview {
                                        statusRow(
                                            icon: "exclamationmark.triangle.fill",
                                            text: usageService.actionCostPreview,
                                            trailing: "\(l10n.t("plan.resetsIn")) \(usageService.timeUntilReset)",
                                            accent: AppColors.warning
                                        )
                                    }
                                    if hasCostPreview && hasSavings { HealthDivider() }
                                    if hasSavings {
                                        statusRow(
                                            icon: "leaf.fill",
                                            text: "\(l10n.t("plan.saves")) \(Int(saved)) \(regionService.currency) \(l10n.t("plan.today"))",
                                            accent: AppColors.success
                                        )
                                    }
                                    if isOverBudget && usageService.canOptimize() {
                                        if hasCostPreview || hasSavings { HealthDivider() }
                                        Button {
                                            usageService.requestAction("optimization", canPerform: usageService.canOptimize()) {
                                                usageService.useOptimize()
                                                viewModel.optimizeDay()
                                            }
                                        } label: {
                                            statusRow(
                                                icon: "wand.and.stars",
                                                text: l10n.t("plan.overBudget"),
                                                trailing: "Optimize →",
                                                accent: AppColors.accent
                                            )
                                        }
                                        .buttonStyle(PressButtonStyle())
                                    }
                                }
                                .transition(.move(edge: .top).combined(with: .opacity))
                                .staggerIn(appeared: appeared, delay: 0.06)
                            }

                            // MARK: Smart Plan + Optimize
                            HStack(spacing: 10) {
                                smartPlanButton
                                optimizeButton
                            }
                            .staggerIn(appeared: appeared, delay: 0.07)

                            // MARK: Daily Stats
                            SectionHeader(l10n.t("plan.highlights"))
                            PlanSummaryCard(summary: planSummary)
                                .staggerIn(appeared: appeared, delay: 0.09)

                            // MARK: AI Insight
                            insightCard
                                .staggerIn(appeared: appeared, delay: 0.12)

                            // MARK: Meals
                            SectionHeader(l10n.t("plan.meals"))
                            VStack(spacing: 10) {
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
            .toolbarBackground(AnyShapeStyle(AppColors.surface), for: .navigationBar)
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
        .background(AppColors.surface, in: Capsule())
        .overlay(
            Capsule()
                .strokeBorder(Color.green.opacity(0.1), lineWidth: 1)
        )
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
        .background(AppColors.surface, in: Capsule())
        .overlay(
            Capsule()
                .strokeBorder(Color.cyan.opacity(0.1), lineWidth: 1)
        )
    }

    // MARK: - Status Row (inside grouped card)

    @ViewBuilder
    private func statusRow(icon: String, text: String, trailing: String? = nil, accent: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(accent)
                .frame(width: 20)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(AppColors.textPrimary)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, 12)
    }

    // MARK: - Plan Summary (assembles display model, no UI logic)

    private var planSummary: PlanSummaryModel {
        let status = viewModel.budgetStatus
        return PlanSummaryModel(
            calories:      viewModel.totalCalories,
            calorieTarget: viewModel.calorieTarget,
            protein:       viewModel.totalProtein,
            proteinTarget: viewModel.proteinTarget,
            cost:          viewModel.totalCost,
            budgetTarget:  viewModel.budgetTarget,
            currency:      regionService.currency,
            statusText:    localizeWithArgs(status.key, args: status.args),
            statusColor:   status.color
        )
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
            .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.red.opacity(0.15), lineWidth: 1)
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
            .background(AppColors.accent, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(PressButtonStyle())
        .disabled(viewModel.isGenerating)
        .opacity(viewModel.isGenerating ? 0.85 : 1)
        .animation(.easeInOut(duration: 0.3), value: viewModel.isGenerating)
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
                            .foregroundStyle(Color.cyan)
                    }
                }
                .frame(width: 22, height: 22)

                Text(l10n.t("plan.optimize"))
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 72)
            .padding(.vertical, 14)
            .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.04), lineWidth: 1)
            )
        }
        .buttonStyle(PressButtonStyle())
        .disabled(viewModel.isOptimizing || viewModel.filledCount == 0)
        .opacity(viewModel.filledCount == 0 ? 0.4 : 1)
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
        .productCard(cornerRadius: 16)
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
                            .fill(Color.orange)
                            .frame(width: geo.size.width * CGFloat(viewModel.weekDaysCompleted) / 7.0)
                            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: viewModel.weekDaysCompleted)
                    }
                }
                .frame(height: 8)
                .clipShape(Capsule())
            }
            .padding(16)
            .productCard(cornerRadius: 18)

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
                                            .fill(cals > viewModel.calorieTarget ? Color.red : Color.orange)
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
                    .productCard(cornerRadius: 16)
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

#Preview {
    PlanView()
        .environmentObject(PlanViewModel())
        .environmentObject(RegionService())
        .environmentObject(UsageService())
        .environmentObject(LocalizationService())
}
