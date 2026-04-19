//
//  RecipesView.swift
//  ChefOS
//

import SwiftUI

// MARK: - Features/Recipes

struct RecipesView: View {
    @StateObject private var viewModel = RecipesViewModel()
    @EnvironmentObject var planViewModel: PlanViewModel
    @EnvironmentObject var regionService: RegionService
    @EnvironmentObject var usageService: UsageService
    @State private var appeared = false
    @State private var mealPickerRecipe: Recipe? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient.screenBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        modeToggle
                            .staggerIn(appeared: appeared, delay: 0)

                        if viewModel.showStock {
                            stockView
                        } else {
                            cookView
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .padding(.bottom, 80)
                }

                // Cooked banner
                if viewModel.showCookedBanner {
                    VStack {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 10) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(.green)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Cooked!")
                                        .font(.subheadline.weight(.bold))
                                    Text(viewModel.lastCookedTitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            // Deduction lines
                            if !viewModel.cookDeductions.isEmpty {
                                VStack(alignment: .leading, spacing: 3) {
                                    ForEach(viewModel.cookDeductions, id: \.self) { line in
                                        Text(line)
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(.orange)
                                    }
                                }
                                .padding(.leading, 44)
                            }
                            Text("Stock updated")
                                .font(.caption2)
                                .foregroundStyle(.green.opacity(0.7))
                                .padding(.leading, 44)
                        }
                        .padding(16)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.green.opacity(0.2), lineWidth: 1)
                        )
                        .shadow(color: .green.opacity(0.15), radius: 16, y: 6)
                        .padding(.horizontal)
                        .transition(.move(edge: .top).combined(with: .opacity))

                        Spacer()
                    }
                    .padding(.top, 8)
                }
            }
            .searchable(text: $viewModel.searchText, prompt: viewModel.showStock ? "Search stock" : "Search recipes")
            .navigationTitle("Recipes")
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .navigationDestination(for: UUID.self) { id in
                if let recipe = viewModel.recipes.first(where: { $0.id == id }) {
                    RecipeDetailView(recipe: recipe, viewModel: viewModel, planViewModel: planViewModel, currency: regionService.currency)
                }
            }
            .onAppear {
                withAnimation(.easeOut(duration: 0.5)) {
                    appeared = true
                }
            }
            .sheet(item: $mealPickerRecipe) { recipe in
                MealSlotPicker(recipe: recipe, planViewModel: planViewModel)
                    .presentationDetents([.height(280)])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: - Mode Toggle

    private var modeToggle: some View {
        HStack(spacing: 0) {
            ForEach(["Stock", "Cook"], id: \.self) { mode in
                let isActive = (mode == "Stock" && viewModel.showStock) || (mode == "Cook" && !viewModel.showStock)
                Button {
                    withAnimation(.snappy(duration: 0.35)) {
                        viewModel.showStock = (mode == "Stock")
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: mode == "Stock" ? "shippingbox.fill" : "frying.pan.fill")
                            .font(.caption)
                        Text(mode)
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(isActive ? .white : .white.opacity(0.4))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 9)
                    .background {
                        if isActive {
                            Capsule()
                                .fill(
                                    mode == "Stock"
                                        ? LinearGradient(colors: [.green, Color(red: 0.2, green: 0.7, blue: 0.3)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                        : LinearGradient(colors: [.orange, Color(red: 0.9, green: 0.4, blue: 0.1)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                                .shadow(color: (mode == "Stock" ? Color.green : Color.orange).opacity(0.3), radius: 10, y: 3)
                        }
                    }
                    .animation(.snappy(duration: 0.3), value: isActive)
                }
                .buttonStyle(PressButtonStyle())
            }
        }
        .padding(3)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1))
        .frame(maxWidth: .infinity, alignment: .center)
    }

    // MARK: - Stock View

    private var stockView: some View {
        VStack(spacing: 14) {
            stockSummary
                .staggerIn(appeared: appeared, delay: 0.03)

            stockFilters
                .staggerIn(appeared: appeared, delay: 0.06)

            ForEach(Array(viewModel.groupedStock.enumerated()), id: \.element.category) { gi, group in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: group.category.icon)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(group.category.rawValue)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        Spacer()
                        Text("\(group.items.count)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 4)
                    .staggerIn(appeared: appeared, delay: 0.09 + Double(gi) * 0.04)

                    ForEach(Array(group.items.enumerated()), id: \.element.id) { index, item in
                        StockItemRow(item: item, currency: regionService.currency)
                            .staggerIn(appeared: appeared, delay: 0.12 + Double(gi) * 0.04 + Double(index) * 0.02)
                    }
                }
            }

            if viewModel.filteredStock.isEmpty {
                emptyStockState
            }
        }
    }

    private var stockSummary: some View {
        HStack(spacing: 0) {
            stockMetric(value: String(format: "%.0f %@", viewModel.totalStockValue, regionService.currency), label: "Total", color: .green, icon: "banknote.fill")
            Divider().frame(height: 36).overlay(Color.white.opacity(0.06))
            stockMetric(value: "\(viewModel.stockItems.count)", label: "Items", color: .cyan, icon: "shippingbox.fill")
            Divider().frame(height: 36).overlay(Color.white.opacity(0.06))
            stockMetric(value: "\(viewModel.expiringCount)", label: "Expiring", color: viewModel.expiringCount > 0 ? .red : .secondary, icon: "exclamationmark.triangle.fill")
        }
        .padding(.vertical, 16)
        .glassCard(cornerRadius: 18)
    }

    private func stockMetric(value: String, label: String, color: Color, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color.opacity(0.7))
            Text(value)
                .font(.headline.weight(.bold))
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var stockFilters: some View {
        HStack(spacing: 8) {
            ForEach(RecipesViewModel.StockFilter.allCases, id: \.self) { filter in
                let isActive = viewModel.stockFilter == filter
                Button {
                    withAnimation(.snappy(duration: 0.3)) {
                        viewModel.stockFilter = filter
                    }
                } label: {
                    Text(filter.rawValue)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(isActive ? .white : .secondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background {
                            if isActive {
                                Capsule().fill(Color.green.opacity(0.6))
                            } else {
                                Capsule().fill(.ultraThinMaterial)
                            }
                        }
                        .overlay(Capsule().stroke(Color.white.opacity(isActive ? 0 : 0.06), lineWidth: 1))
                }
                .buttonStyle(PressButtonStyle())
            }
            Spacer()
        }
    }

    private var emptyStockState: some View {
        VStack(spacing: 8) {
            Image(systemName: "shippingbox")
                .font(.largeTitle)
                .foregroundStyle(.secondary.opacity(0.5))
            Text("No items found")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Text("Scan a receipt in Chat to add items")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Strategy Block

    private var strategyBlock: some View {
        let tips = viewModel.strategyTips(plan: planViewModel)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "brain.head.profile.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.purple)
                Text("Strategy for today")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.purple)
                Spacer()
            }

            ForEach(tips) { tip in
                HStack(spacing: 8) {
                    Image(systemName: tip.icon)
                        .font(.caption2)
                        .foregroundStyle(tip.color)
                        .frame(width: 18)
                    Text(tip.text)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.primary.opacity(0.85))
                }
            }
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.purple.opacity(0.15), lineWidth: 1)
                )
        }
        .shadow(color: .purple.opacity(0.08), radius: 8, y: 3)
    }

    // MARK: - Cook View

    private var cookView: some View {
        VStack(spacing: 14) {
            // Strategy block
            strategyBlock
                .staggerIn(appeared: appeared, delay: 0.02)

            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .foregroundStyle(.orange)
                Text("Based on your stock")
                    .font(.subheadline.weight(.bold))
                Spacer()
            }
            .staggerIn(appeared: appeared, delay: 0.04)

            cookFilters
                .staggerIn(appeared: appeared, delay: 0.06)

            if viewModel.cookFilter == .all {
                if !viewModel.canCookRecipes.isEmpty {
                    cookSection(title: "Can cook now", icon: "checkmark.circle.fill", color: .green, recipes: viewModel.canCookRecipes, canCook: true)
                }
                if !viewModel.missingRecipes.isEmpty {
                    cookSection(title: "Missing ingredients", icon: "exclamationmark.triangle.fill", color: .orange, recipes: viewModel.missingRecipes, canCook: false)
                }
            } else {
                ForEach(Array(viewModel.filteredRecipes.enumerated()), id: \.element.id) { index, recipe in
                    NavigationLink(value: recipe.id) {
                        CookRecipeRow(recipe: recipe, canCook: viewModel.canCook(recipe), viewModel: viewModel, planViewModel: planViewModel, onAddToPlan: { mealPickerRecipe = recipe }, currency: regionService.currency)
                    }
                    .buttonStyle(.plain)
                    .staggerIn(appeared: appeared, delay: 0.09 + Double(index) * 0.04)
                }
            }

            if viewModel.filteredRecipes.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "frying.pan")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary.opacity(0.5))
                    Text("No recipes found")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            }
        }
    }

    private var cookFilters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(RecipesViewModel.CookFilter.allCases, id: \.self) { filter in
                    let isActive = viewModel.cookFilter == filter
                    Button {
                        withAnimation(.snappy(duration: 0.3)) {
                            viewModel.cookFilter = filter
                        }
                    } label: {
                        Text(filter.rawValue)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(isActive ? .white : .secondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background {
                                if isActive {
                                    Capsule().fill(Color.orange.opacity(0.6))
                                } else {
                                    Capsule().fill(.ultraThinMaterial)
                                }
                            }
                            .overlay(Capsule().stroke(Color.white.opacity(isActive ? 0 : 0.06), lineWidth: 1))
                    }
                    .buttonStyle(PressButtonStyle())
                }
            }
        }
    }

    private func cookSection(title: String, icon: String, color: Color, recipes: [Recipe], canCook: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(.subheadline.weight(.bold))
                Spacer()
                Text("\(recipes.count)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(color.opacity(0.12), in: Capsule())
            }

            ForEach(Array(recipes.enumerated()), id: \.element.id) { index, recipe in
                NavigationLink(value: recipe.id) {
                    CookRecipeRow(recipe: recipe, canCook: canCook, viewModel: viewModel, planViewModel: planViewModel, onAddToPlan: { mealPickerRecipe = recipe }, currency: regionService.currency)
                }
                .buttonStyle(.plain)
                .staggerIn(appeared: appeared, delay: 0.09 + Double(index) * 0.04)
            }
        }
    }
}

// MARK: - StockItemRow

struct StockItemRow: View {
    let item: StockItem
    let currency: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: item.category.icon)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(item.name)
                        .font(.subheadline.weight(.semibold))
                    if item.isExpiringSoon {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundStyle(.red)
                    }
                }
                HStack(spacing: 8) {
                    Text("\(formattedQuantity) \(item.unit.rawValue)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("·").foregroundStyle(.tertiary)
                    Text(item.store)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(String(format: "%.2f %@", item.totalPrice, currency))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.green)
                if let exp = item.expiresIn {
                    Text(exp <= 1 ? "expires today" : "\(exp)d left")
                        .font(.caption2)
                        .foregroundStyle(exp <= 3 ? .red : .secondary)
                }
            }
        }
        .padding(14)
        .glassCard(cornerRadius: 16)
        .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
        .overlay {
            if item.isExpiringSoon {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color.red.opacity(0.2), lineWidth: 1)
            }
        }
    }

    private var formattedQuantity: String {
        item.quantity.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", item.quantity)
            : String(format: "%.1f", item.quantity)
    }

    private var iconColor: Color {
        if item.isExpiringSoon { return .red }
        if item.isLow { return .orange }
        return .green
    }
}

// MARK: - CookRecipeRow

struct CookRecipeRow: View {
    let recipe: Recipe
    let canCook: Bool
    @ObservedObject var viewModel: RecipesViewModel
    var planViewModel: PlanViewModel?
    var onAddToPlan: (() -> Void)? = nil
    var currency: String = "$"
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(canCook
                            ? LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing)
                            : LinearGradient(colors: [.orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .frame(width: 50, height: 50)
                    Image(systemName: canCook ? "checkmark.seal.fill" : "fork.knife")
                        .font(.title3)
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(recipe.title)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    HStack(spacing: 8) {
                        if canCook {
                            HStack(spacing: 3) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.green)
                                Text("can cook now")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.green)
                            }
                        } else {
                            let missing = viewModel.missingIngredients(for: recipe)
                            HStack(spacing: 3) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                                Text("missing \(missing.count)")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.orange)
                            }
                        }

                        if let slot = planViewModel?.plannedSlot(for: recipe) {
                            HStack(spacing: 3) {
                                Image(systemName: "calendar.badge.checkmark")
                                    .font(.caption2)
                                    .foregroundStyle(.cyan)
                                Text(slot)
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.cyan)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.cyan.opacity(0.12), in: Capsule())
                        }
                    }

                    HStack(spacing: 8) {
                        HStack(spacing: 3) {
                            Image(systemName: "banknote.fill")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text("\(String(format: "%.2f %@", recipe.costPerServing, currency)) / portion")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                        HStack(spacing: 3) {
                            Image(systemName: "bolt.fill")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text("\(recipe.calories) kcal")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                        }

                        let tag = viewModel.priceTag(for: recipe)
                        Text(tag.label)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(tag.color)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(tag.color.opacity(0.12), in: Capsule())
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            // Ingredient usage — collapsible
            let statuses = viewModel.ingredientStatus(for: recipe)
            if !statuses.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Button {
                        withAnimation(.snappy(duration: 0.3)) {
                            expanded.toggle()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(expanded ? "Hide ingredients" : "Show ingredients")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.secondary)
                            Image(systemName: expanded ? "chevron.up" : "chevron.down")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if expanded {
                        ForEach(Array(statuses)) { s in
                            HStack(spacing: 6) {
                                Image(systemName: s.inStock ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .font(.caption2)
                                    .foregroundStyle(s.inStock ? .green : .red)
                                Text("\(s.name) \(s.qty)")
                                    .font(.caption2)
                                    .foregroundStyle(s.inStock ? .primary : .secondary)
                                if s.inStock {
                                    Text("(OK)")
                                        .font(.caption2)
                                        .foregroundStyle(.green.opacity(0.7))
                                }
                            }
                        }
                    }
                }
                .padding(.leading, 64)
            }

            // Action buttons
            HStack(spacing: 10) {
                if canCook {
                    Button {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                            viewModel.cookRecipe(recipe)
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "flame.fill")
                                .font(.caption2)
                            Text("Cook")
                                .font(.caption.weight(.bold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            LinearGradient(colors: [.orange, Color(red: 0.9, green: 0.3, blue: 0.1)], startPoint: .topLeading, endPoint: .bottomTrailing),
                            in: Capsule()
                        )
                        .shadow(color: .orange.opacity(0.3), radius: 6, y: 2)
                    }
                    .buttonStyle(PressButtonStyle())

                    Button {
                        onAddToPlan?()
                    } label: {
                        HStack(spacing: 5) {
                            if planViewModel?.plannedSlot(for: recipe) != nil {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption2)
                                Text("Added")
                                    .font(.caption.weight(.bold))
                            } else {
                                Image(systemName: "calendar.badge.plus")
                                    .font(.caption2)
                                Text("Add to plan")
                                    .font(.caption.weight(.bold))
                            }
                        }
                        .foregroundStyle(planViewModel?.plannedSlot(for: recipe) != nil ? .cyan : .secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1))
                    }
                    .buttonStyle(PressButtonStyle())
                    .disabled(planViewModel?.plannedSlot(for: recipe) != nil)
                } else {
                    Button {
                        viewModel.addToShoppingList(recipe: recipe)
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "cart.badge.plus")
                                .font(.caption2)
                            Text("Add to shopping list")
                                .font(.caption.weight(.bold))
                        }
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.orange.opacity(0.08), in: Capsule())
                        .overlay(Capsule().stroke(Color.orange.opacity(0.15), lineWidth: 1))
                    }
                    .buttonStyle(PressButtonStyle())
                }

                Spacer()
            }
            .padding(.leading, 64)
        }
        .padding(14)
        .glassCard(cornerRadius: 18)
        .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
        .overlay {
            if canCook {
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(Color.green.opacity(0.15), lineWidth: 1)
            }
        }
        .opacity(viewModel.cookedRecipeId == recipe.id ? 0.3 : 1.0)
        .scaleEffect(viewModel.cookedRecipeId == recipe.id ? 0.97 : 1.0)
        .animation(.easeOut(duration: 0.4), value: viewModel.cookedRecipeId)
    }
}

// MARK: - RecipeDetailView

struct RecipeDetailView: View {
    let recipe: Recipe
    @ObservedObject var viewModel: RecipesViewModel
    var planViewModel: PlanViewModel?
    var currency: String = "$"
    @State private var showMealPicker = false

    private var missing: [String] {
        viewModel.missingIngredients(for: recipe)
    }

    private var canCookNow: Bool {
        viewModel.canCook(recipe)
    }

    var body: some View {
        ZStack {
            LinearGradient.screenBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "fork.knife.circle.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(.orange)

                        Text(recipe.title)
                            .font(.title.bold())
                            .multilineTextAlignment(.center)

                        HStack(spacing: 16) {
                            Label("\(recipe.calories) kcal", systemImage: "flame.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.orange)
                            Label("\(recipe.protein)g", systemImage: "bolt.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.cyan)
                            Label("\(recipe.servings) srv", systemImage: "person.2.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.purple)
                        }

                        // Economics
                        HStack(spacing: 20) {
                            VStack(spacing: 2) {
                                Text(String(format: "%.2f %@", recipe.estimatedCost, currency))
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(.green)
                                Text("total")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Divider().frame(height: 30).overlay(Color.white.opacity(0.06))
                            VStack(spacing: 2) {
                                Text(String(format: "%.2f %@", recipe.costPerServing, currency))
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(.green)
                                Text("/ portion")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Divider().frame(height: 30).overlay(Color.white.opacity(0.06))
                            VStack(spacing: 2) {
                                let pct = viewModel.budgetPercent(for: recipe)
                                Text("\(pct)%")
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(pct <= 15 ? .green : pct <= 30 ? .orange : .red)
                                Text("of budget")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                        HStack(spacing: 6) {
                            Image(systemName: canCookNow ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            Text(canCookNow ? "All ingredients in stock" : "Missing \(missing.count) ingredient\(missing.count == 1 ? "" : "s")")
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(canCookNow ? .green : .orange)
                        .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .glassCard(cornerRadius: 24)

                    // Ingredients with quantities
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Ingredients", systemImage: "basket.fill")
                            .font(.title3.bold())
                            .foregroundStyle(.primary)

                        let statuses = viewModel.ingredientStatus(for: recipe)
                        ForEach(statuses, id: \.id) { (s: RecipesViewModel.IngredientStatus) in
                            HStack(spacing: 10) {
                                Image(systemName: s.inStock ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(s.inStock ? .green : .red)
                                Text(s.name)
                                    .foregroundStyle(s.inStock ? Color.primary : Color.secondary)
                                Spacer()
                                Text(s.qty)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(s.inStock ? Color.primary : Color.red)
                                Text(s.inStock ? "OK" : "missing")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(s.inStock ? .green : .red)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background((s.inStock ? Color.green : Color.red).opacity(0.1), in: Capsule())
                            }
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassCard(cornerRadius: 20)

                    // Actions
                    HStack(spacing: 12) {
                        if canCookNow {
                            Button {
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                    viewModel.cookRecipe(recipe)
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "flame.fill")
                                    Text("Cook now")
                                        .font(.headline.weight(.bold))
                                }
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    LinearGradient(colors: [.orange, Color(red: 0.9, green: 0.3, blue: 0.1)], startPoint: .topLeading, endPoint: .bottomTrailing),
                                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                                )
                                .shadow(color: .orange.opacity(0.3), radius: 10, y: 4)
                            }
                            .buttonStyle(PressButtonStyle())

                            Button {
                                showMealPicker = true
                            } label: {
                                HStack(spacing: 6) {
                                    if let slot = planViewModel?.plannedSlot(for: recipe) {
                                        Image(systemName: "checkmark.circle.fill")
                                        Text(slot)
                                            .font(.headline.weight(.bold))
                                    } else {
                                        Image(systemName: "calendar.badge.plus")
                                        Text("Plan")
                                            .font(.headline.weight(.bold))
                                    }
                                }
                                .foregroundStyle(planViewModel?.plannedSlot(for: recipe) != nil ? .cyan : .secondary)
                                .padding(.vertical, 14)
                                .padding(.horizontal, 24)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))
                            }
                            .buttonStyle(PressButtonStyle())
                        } else {
                            Button {
                                viewModel.addToShoppingList(recipe: recipe)
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "cart.badge.plus")
                                    Text("Add missing to shopping list")
                                        .font(.headline.weight(.bold))
                                }
                                .foregroundStyle(.orange)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.orange.opacity(0.15), lineWidth: 1))
                            }
                            .buttonStyle(PressButtonStyle())
                        }
                    }

                    // Steps
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Steps", systemImage: "list.number")
                            .font(.title3.bold())
                            .foregroundStyle(.primary)

                        ForEach(Array(recipe.steps.enumerated()), id: \.offset) { index, step in
                            HStack(alignment: .top, spacing: 12) {
                                Text("\(index + 1)")
                                    .font(.caption.bold())
                                    .foregroundStyle(.white)
                                    .frame(width: 24, height: 24)
                                    .background(LinearGradient(colors: [.orange, Color(red: 0.9, green: 0.4, blue: 0.1)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .clipShape(Circle())
                                Text(step)
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassCard(cornerRadius: 20)
                }
                .padding()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .sheet(isPresented: $showMealPicker) {
            if let pvm = planViewModel {
                MealSlotPicker(recipe: recipe, planViewModel: pvm)
                    .presentationDetents([.height(280)])
                    .presentationDragIndicator(.visible)
            }
        }
    }
}

#Preview {
    RecipesView()
        .environmentObject(PlanViewModel())
        .environmentObject(RegionService())
        .environmentObject(UsageService())
}

// MARK: - Meal Slot Picker

struct MealSlotPicker: View {
    let recipe: Recipe
    @ObservedObject var planViewModel: PlanViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 6) {
                Image(systemName: "calendar.badge.plus")
                    .font(.title2)
                    .foregroundStyle(.orange)
                Text("Add to plan")
                    .font(.headline.weight(.bold))
                Text(recipe.title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 8)

            VStack(spacing: 10) {
                ForEach(Meal.MealType.allCases, id: \.self) { type in
                    let isFilled = !(planViewModel.emptySlots.contains { $0.type == type }) && planViewModel.weekDays.indices.contains(planViewModel.selectedDayIndex) && planViewModel.weekDays[planViewModel.selectedDayIndex].meals.contains { $0.type == type && $0.recipe != nil }

                    Button {
                        planViewModel.addRecipeToPlan(recipe, mealType: type)
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: mealIcon(type))
                                .font(.body.weight(.semibold))
                                .foregroundStyle(mealColor(type))
                                .frame(width: 32)
                            Text(type.rawValue)
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            if isFilled {
                                Text("Replace")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.orange)
                            } else {
                                Text("Empty")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.green)
                            }
                        }
                        .padding(14)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.white.opacity(0.06), lineWidth: 1))
                    }
                    .buttonStyle(PressButtonStyle())
                }
            }
            .padding(.horizontal)

            Spacer()
        }
        .presentationBackground(.ultraThinMaterial)
    }

    private func mealIcon(_ type: Meal.MealType) -> String {
        switch type {
        case .breakfast: return "sunrise.fill"
        case .lunch: return "sun.max.fill"
        case .dinner: return "moon.stars.fill"
        }
    }

    private func mealColor(_ type: Meal.MealType) -> Color {
        switch type {
        case .breakfast: return .orange
        case .lunch: return .yellow
        case .dinner: return .indigo
        }
    }
}
