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
    @EnvironmentObject var l10n: LocalizationService
    @State private var appeared = false
    @State private var mealPickerRecipe: Recipe? = nil
    @State private var expandedItems: Set<String> = []
    @StateObject private var stockVM = StockViewModel()
    @State private var showCookSuggestions = false
    @StateObject private var cookVM = CookSuggestionsViewModel()

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
                                    Text(l10n.t("recipes.cooked"))
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
                            Text(l10n.t("recipes.stockUpdated"))
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
            .searchable(text: $viewModel.searchText, prompt: viewModel.showStock ? l10n.t("recipes.searchStock") : l10n.t("recipes.search"))
            .navigationTitle(l10n.t("recipes.title"))
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
            .task {
                await stockVM.loadInventory()
            }
            .sheet(item: $mealPickerRecipe) { recipe in
                MealSlotPicker(recipe: recipe, planViewModel: planViewModel)
                    .presentationDetents([.height(280)])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $stockVM.showAddSheet) {
                // Reload inventory after adding
                Task { await stockVM.loadInventory() }
            } content: {
                CatalogSearchSheet(vm: stockVM)
                    .environmentObject(l10n)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showCookSuggestions) {
                CookSuggestionsSheet(vm: cookVM)
                    .environmentObject(l10n)
                    .environmentObject(regionService)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: - Mode Toggle

    private var currencySymbol: String {
        RegionService.supportedCountries.first { $0.code == regionService.countryCode }?.currencySymbol ?? regionService.currency
    }

    private var modeToggle: some View {
        HStack(spacing: 0) {
            ForEach([("Stock", l10n.t("recipes.stock")), ("Cook", l10n.t("recipes.cook"))], id: \.0) { mode, label in
                let isActive = (mode == "Stock" && viewModel.showStock) || (mode == "Cook" && !viewModel.showStock)
                Button {
                    withAnimation(.snappy(duration: 0.35)) {
                        viewModel.showStock = (mode == "Stock")
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: mode == "Stock" ? "shippingbox.fill" : "frying.pan.fill")
                            .font(.caption)
                        Text(label)
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
            // Add product button
            Button {
                stockVM.showAddSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.body)
                    Text(l10n.t("recipes.addProduct"))
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.green.gradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(PressButtonStyle())
            .staggerIn(appeared: appeared, delay: 0.01)

            // 🧠 Smart Insight Block
            if !stockVM.items.isEmpty {
                smartInsightBlock
                    .staggerIn(appeared: appeared, delay: 0.02)
            }

            stockSummary
                .staggerIn(appeared: appeared, delay: 0.03)

            stockFilters
                .staggerIn(appeared: appeared, delay: 0.06)

            // Group by category → then by product
            ForEach(Array(stockVM.groupedByCategory.enumerated()), id: \.element.category) { gi, catGroup in
                VStack(alignment: .leading, spacing: 8) {
                    // Category header with emoji + value
                    HStack(spacing: 8) {
                        Text(StockViewModel.categoryEmoji(catGroup.category))
                            .font(.caption)
                        Image(systemName: stockCategoryIcon(catGroup.category))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(catGroup.category)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        Text("•")
                            .foregroundStyle(.tertiary)
                        Text(String(format: "%.0f %@", stockVM.categoryValue(catGroup.category), currencySymbol))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.green.opacity(0.8))
                        Spacer()
                        Text("\(catGroup.groups.count)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 4)
                    .staggerIn(appeared: appeared, delay: 0.09 + Double(gi) * 0.04)

                    // Product groups
                    ForEach(Array(catGroup.groups.enumerated()), id: \.element.id) { pi, group in
                        ProductGroupRow(
                            group: group,
                            currency: currencySymbol,
                            isExpanded: expandedItems.contains(group.id),
                            onTap: {
                                withAnimation(.snappy(duration: 0.3)) {
                                    if expandedItems.contains(group.id) {
                                        expandedItems.remove(group.id)
                                    } else {
                                        expandedItems.insert(group.id)
                                    }
                                }
                            },
                            onDelete: { item in
                                Task {
                                    await stockVM.deleteProduct(item)
                                    await stockVM.loadInventory()
                                }
                            }
                        )
                        .staggerIn(appeared: appeared, delay: 0.12 + Double(gi) * 0.04 + Double(pi) * 0.03)
                    }
                }
            }

            if stockVM.filteredItems.isEmpty && !stockVM.isLoading {
                emptyStockState
            }

            if stockVM.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            }
        }
    }

    private var stockSummary: some View {
        HStack(spacing: 0) {
            stockMetric(value: String(format: "%.0f %@", stockVM.totalValue, currencySymbol), label: l10n.t("recipes.total"), color: .green, icon: "banknote.fill")
            Divider().frame(height: 36).overlay(Color.white.opacity(0.06))
            stockMetric(value: "\(stockVM.items.count)", label: l10n.t("recipes.items"), color: .cyan, icon: "shippingbox.fill")
            Divider().frame(height: 36).overlay(Color.white.opacity(0.06))
            stockMetric(value: "\(stockVM.expiringCount)", label: l10n.t("recipes.expiring"), color: stockVM.expiringCount > 0 ? .red : .secondary, icon: "exclamationmark.triangle.fill")
            if stockVM.wasteRiskValue > 0 {
                Divider().frame(height: 36).overlay(Color.white.opacity(0.06))
                stockMetric(value: String(format: "%.0f %@", stockVM.wasteRiskValue, currencySymbol), label: l10n.t("recipes.atRisk"), color: .red, icon: "flame.fill")
            }
        }
        .padding(.vertical, 16)
        .glassCard(cornerRadius: 18)
    }

    // MARK: - Smart Insight Block
    private var smartInsightBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: "brain.head.profile")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.cyan)
                Text(l10n.t("recipes.smartInsight"))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.cyan)
                    .textCase(.uppercase)
                Spacer()
                // Days of food badge
                if stockVM.estimatedDaysOfFood > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 9))
                        Text("~\(stockVM.estimatedDaysOfFood) " + l10n.t("recipes.days"))
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.cyan.opacity(0.2)))
                }
            }

            // Status line — always show something useful
            HStack(spacing: 8) {
                Image(systemName: stockVM.urgentItems.isEmpty ? "leaf.fill" : "bolt.fill")
                    .font(.caption2)
                    .foregroundStyle(stockVM.urgentItems.isEmpty ? .green : .orange)
                Text(insightStatusLine)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary.opacity(0.85))
            }

            // Urgent items with emoji
            ForEach(stockVM.urgentItems.prefix(3)) { item in
                HStack(spacing: 8) {
                    Text(StockViewModel.categoryEmoji(item.category))
                        .font(.caption)
                    Text(insightExpiryText(item))
                        .font(.caption)
                        .foregroundStyle(.primary.opacity(0.9))
                    Spacer()
                    Text(String(format: "%.2f %@", item.totalPrice, currencySymbol))
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.red.opacity(0.8))
                }
            }

            // Waste risk
            if stockVM.wasteRiskValue > 0 {
                HStack(spacing: 8) {
                    Image(systemName: "flame.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                    Text(l10n.t("recipes.insightWaste") + " " + String(format: "%.0f %@", stockVM.wasteRiskValue, currencySymbol))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.orange)
                }
            }

            // ✨ Action button — "What to cook?"
            Button {
                showCookSuggestions = true
                Task { await cookVM.loadSuggestions() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.caption.weight(.bold))
                    Text(l10n.t("recipes.whatToCook"))
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    LinearGradient(
                        colors: [.purple, .blue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                )
            }
            .buttonStyle(PressButtonStyle())
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            stockVM.urgentItems.isEmpty
                                ? Color.cyan.opacity(0.12)
                                : Color.orange.opacity(0.15),
                            lineWidth: 1
                        )
                }
        }
    }

    /// Dynamic status text
    private var insightStatusLine: String {
        let count = stockVM.items.count
        let days = stockVM.estimatedDaysOfFood
        let urgent = stockVM.urgentItems.count

        if count == 0 {
            return l10n.t("recipes.insightEmpty")
        } else if urgent > 0 {
            return String(format: l10n.t("recipes.insightUrgent"), urgent)
        } else {
            return String(format: l10n.t("recipes.insightGood"), days)
        }
    }

    private func insightExpiryText(_ item: StockItem) -> String {
        let days = item.expiresIn ?? 0
        if days <= 0 {
            return "\(item.name) — " + l10n.t("recipes.insightExpired")
        } else if days == 1 {
            return "\(item.name) — " + l10n.t("recipes.insightTomorrow")
        } else {
            return "\(item.name) — \(days) " + l10n.t("recipes.insightDaysLeft")
        }
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
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(stockVM.availableFilters, id: \.self) { filter in
                    let isActive = stockVM.stockFilter == filter
                    Button {
                        withAnimation(.snappy(duration: 0.3)) {
                            stockVM.stockFilter = filter
                        }
                    } label: {
                        HStack(spacing: 5) {
                            if let icon = filterIcon(filter) {
                                Image(systemName: icon)
                                    .font(.system(size: 10, weight: .bold))
                            }
                            Text(filterTitle(filter))
                                .font(.caption.weight(.semibold))
                            if let count = filterCount(filter), count > 0 {
                                Text("\(count)")
                                    .font(.system(size: 9, weight: .bold))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(isActive ? Color.white.opacity(0.25) : Color.white.opacity(0.08)))
                            }
                        }
                        .foregroundStyle(isActive ? .white : .secondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background {
                            if isActive {
                                Capsule().fill(filterColor(filter).opacity(0.6))
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

    private func filterTitle(_ filter: StockViewModel.StockFilter) -> String {
        switch filter {
        case .all: return l10n.t("recipes.filterAll")
        case .expiring: return l10n.t("recipes.filterExpiring")
        case .low: return l10n.t("recipes.filterLow")
        case .category(let cat): return cat   // already localized from backend
        }
    }

    private func filterIcon(_ filter: StockViewModel.StockFilter) -> String? {
        switch filter {
        case .all: return nil
        case .expiring: return "exclamationmark.triangle.fill"
        case .low: return "arrow.down.circle.fill"
        case .category(let cat): return stockCategoryIcon(cat)
        }
    }

    private func filterColor(_ filter: StockViewModel.StockFilter) -> Color {
        switch filter {
        case .all: return .green
        case .expiring: return .red
        case .low: return .orange
        case .category: return .cyan
        }
    }

    private func filterCount(_ filter: StockViewModel.StockFilter) -> Int? {
        switch filter {
        case .all: return stockVM.items.count
        case .expiring: return stockVM.expiringCount
        case .low: return stockVM.lowCount
        case .category(let cat): return stockVM.items.filter { $0.category == cat }.count
        }
    }

    private var emptyStockState: some View {
        VStack(spacing: 8) {
            Image(systemName: "shippingbox")
                .font(.largeTitle)
                .foregroundStyle(.secondary.opacity(0.5))
            Text(l10n.t("recipes.noItems"))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Text(l10n.t("recipes.scanReceipt"))
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Strategy Block

    // MARK: - Cook View

    private var cookView: some View {
        VStack(spacing: 14) {
            let itemCount = stockVM.items.count

            if stockVM.isLoading {
                // Loading state
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.3)
                    Text(l10n.t("cook.analyzing"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)

            } else if itemCount == 0 {
                // 🟢 State 1 — EMPTY INVENTORY
                cookEmptyState
                    .staggerIn(appeared: appeared, delay: 0.04)

            } else if itemCount < 3 {
                // 🟡 State 2 — INSUFFICIENT (1-2 products)
                cookInsufficientState
                    .staggerIn(appeared: appeared, delay: 0.04)

            } else {
                // 🟢 State 3 — READY (3+ products)
                cookReadyState
                    .staggerIn(appeared: appeared, delay: 0.04)
            }
        }
    }

    // MARK: - Cook State 1: Empty Inventory

    private var cookEmptyState: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 20)

            Image(systemName: "refrigerator")
                .font(.system(size: 56))
                .foregroundStyle(.secondary.opacity(0.4))
                .symbolEffect(.pulse, options: .repeating)

            VStack(spacing: 8) {
                Text(l10n.t("cook.noProducts"))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
                Text(l10n.t("cook.noProductsHint"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }

            VStack(spacing: 10) {
                Button {
                    withAnimation(.snappy(duration: 0.35)) {
                        viewModel.showStock = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        stockVM.showAddSheet = true
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.body)
                        Text(l10n.t("cook.addProducts"))
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.green.gradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(PressButtonStyle())
            }

            // Hint
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .font(.caption)
                    .foregroundStyle(.yellow)
                Text(l10n.t("cook.addHint"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            Spacer().frame(height: 20)
        }
    }

    // MARK: - Cook State 2: Insufficient Products

    @State private var quickAddingProduct: String? = nil

    private var cookInsufficientState: some View {
        VStack(spacing: 16) {
            // What you have
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "shippingbox.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Text(l10n.t("cook.youHave"))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.orange)
                        .textCase(.uppercase)
                }

                FlowLayout(spacing: 6) {
                    ForEach(stockVM.items, id: \.id) { item in
                        HStack(spacing: 4) {
                            Text(StockViewModel.categoryEmoji(item.category))
                                .font(.caption)
                            Text(item.name)
                                .font(.caption.weight(.medium))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.orange.opacity(0.15), in: Capsule())
                        .foregroundStyle(.orange)
                    }
                }
            }
            .padding(14)
            .glassCard(cornerRadius: 16)

            // 🧠 Smart analysis — WHY not enough
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "brain.head.profile")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.cyan)
                    Text(l10n.t("cook.analysis"))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.cyan)
                        .textCase(.uppercase)
                }

                // What's missing
                if !stockVM.hasProtein {
                    analysisRow(icon: "xmark.circle.fill", color: .red, text: l10n.t("cook.noProtein"))
                } else {
                    analysisRow(icon: "checkmark.circle.fill", color: .green, text: l10n.t("cook.hasProtein"))
                }
                if !stockVM.hasBase {
                    analysisRow(icon: "xmark.circle.fill", color: .red, text: l10n.t("cook.noBase"))
                } else {
                    analysisRow(icon: "checkmark.circle.fill", color: .green, text: l10n.t("cook.hasBase"))
                }
                if !stockVM.hasVegetables {
                    analysisRow(icon: "xmark.circle.fill", color: .red, text: l10n.t("cook.noVegetable"))
                } else {
                    analysisRow(icon: "checkmark.circle.fill", color: .green, text: l10n.t("cook.hasVegetable"))
                }

                // Conclusion
                let missingCount = stockVM.missingCategories.count
                HStack(spacing: 8) {
                    Image(systemName: missingCount > 1 ? "exclamationmark.triangle.fill" : "info.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(missingCount > 1 ? .orange : .blue)
                    Text(missingCount > 1 ? l10n.t("cook.cantCookFull") : l10n.t("cook.almostThere"))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.primary.opacity(0.7))
                }
                .padding(.top, 4)
            }
            .padding(14)
            .glassCard(cornerRadius: 16)

            // 🎯 Quick-add buttons (interactive!)
            if !stockVM.hasProtein {
                quickAddSection(
                    emoji: "🥩",
                    title: l10n.t("cook.addProtein"),
                    buttons: [
                        (l10n.t("cook.chicken"), "chicken"),
                        (l10n.t("cook.eggs"), "egg"),
                        (l10n.t("cook.fish"), "fish"),
                    ]
                )
            }
            if !stockVM.hasBase {
                quickAddSection(
                    emoji: "🍚",
                    title: l10n.t("cook.addBase"),
                    buttons: [
                        (l10n.t("cook.rice"), "rice"),
                        (l10n.t("cook.pasta"), "pasta"),
                        (l10n.t("cook.potato"), "potato"),
                    ]
                )
            }
            if !stockVM.hasVegetables {
                quickAddSection(
                    emoji: "🥕",
                    title: l10n.t("cook.addVegetable"),
                    buttons: [
                        (l10n.t("cook.onion"), "onion"),
                        (l10n.t("cook.tomato"), "tomato"),
                        (l10n.t("cook.carrot"), "carrot"),
                    ]
                )
            }

            // 🔒 Unlock effect
            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "lock.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary.opacity(0.5))
                        .symbolEffect(.pulse, options: .repeating)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(l10n.t("cook.recipesLocked"))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                        Text(String(format: l10n.t("cook.addMoreToUnlock"), max(0, 3 - stockVM.items.count)))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                    )
            }

            // ✨ AI fallback — even with few products
            Button {
                showCookSuggestions = true
                Task { await cookVM.loadSuggestions() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.caption.weight(.bold))
                    Text(l10n.t("cook.tryAnyway"))
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                )
            }
            .buttonStyle(PressButtonStyle())

            // Browse catalog
            Button {
                withAnimation(.snappy(duration: 0.35)) {
                    viewModel.showStock = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    stockVM.showAddSheet = true
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                    Text(l10n.t("cook.browseCatalog"))
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(.green)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.green.opacity(0.4), lineWidth: 1.5)
                )
            }
            .buttonStyle(PressButtonStyle())
        }
    }

    private func analysisRow(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(color)
            Text(text)
                .font(.caption.weight(.medium))
                .foregroundStyle(.primary.opacity(0.85))
        }
    }

    private func quickAddSection(emoji: String, title: String, buttons: [(label: String, query: String)]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(emoji)
                    .font(.caption)
                Text("+ " + title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.primary.opacity(0.7))
            }

            FlowLayout(spacing: 6) {
                ForEach(buttons, id: \.query) { btn in
                    quickAddButton(label: btn.label, query: btn.query)
                }
            }
        }
        .padding(14)
        .glassCard(cornerRadius: 16)
    }

    private func quickAddButton(label: String, query: String) -> some View {
        let isAdding = quickAddingProduct == query
        return Button {
            Task {
                quickAddingProduct = query
                let success = await stockVM.quickAddProduct(name: query)
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    quickAddingProduct = nil
                }
                _ = success
            }
        } label: {
            HStack(spacing: 4) {
                if isAdding {
                    ProgressView()
                        .scaleEffect(0.6)
                } else {
                    Image(systemName: "plus")
                        .font(.system(size: 9, weight: .bold))
                }
                Text(label)
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(isAdding ? Color.secondary : Color.green)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .strokeBorder(Color.green.opacity(0.4), lineWidth: 1)
                    .background(Capsule().fill(isAdding ? Color.green.opacity(0.1) : Color.clear))
            )
        }
        .buttonStyle(PressButtonStyle())
        .disabled(quickAddingProduct != nil)
    }

    // MARK: - Cook State 3: Ready (3+ products)

    private var cookReadyState: some View {
        VStack(spacing: 14) {
            // Inventory summary chip
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundStyle(.orange)
                Text(l10n.t("recipes.basedOnStock"))
                    .font(.subheadline.weight(.bold))
                Spacer()
                Text("\(stockVM.items.count) " + l10n.t("recipes.items").lowercased())
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            // Available ingredients
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "leaf.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                    Text(l10n.t("cook.yourIngredients"))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.green)
                        .textCase(.uppercase)
                }

                FlowLayout(spacing: 5) {
                    ForEach(stockVM.items.prefix(12), id: \.id) { item in
                        HStack(spacing: 3) {
                            Text(StockViewModel.categoryEmoji(item.category))
                                .font(.system(size: 10))
                            Text(item.name)
                                .font(.caption2.weight(.medium))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.green.opacity(0.12), in: Capsule())
                        .foregroundStyle(.green)
                    }
                    if stockVM.items.count > 12 {
                        Text("+\(stockVM.items.count - 12)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Color.white.opacity(0.06), in: Capsule())
                    }
                }
            }
            .padding(14)
            .glassCard(cornerRadius: 16)

            // AI Suggestions
            if cookVM.isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text(l10n.t("cook.analyzing"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else if let error = cookVM.errorMessage {
                VStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title3)
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button(l10n.t("cook.retry")) {
                        Task { await cookVM.loadSuggestions() }
                    }
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.borderedProminent)
                }
                .padding(.vertical, 20)
            } else if cookVM.hasLoaded && cookVM.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "frying.pan")
                        .font(.title2)
                        .foregroundStyle(.secondary.opacity(0.5))
                    Text(l10n.t("cook.noRecipesFound"))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                    Text(l10n.t("cook.tryAddMore"))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else if cookVM.hasLoaded {
                // Real suggestions from backend
                if !cookVM.canCook.isEmpty {
                    suggestionSection(
                        title: l10n.t("cook.canCookNow"),
                        icon: "checkmark.circle.fill",
                        color: .green,
                        dishes: cookVM.canCook
                    )
                }
                if !cookVM.almost.isEmpty {
                    suggestionSection(
                        title: l10n.t("cook.almostReady"),
                        icon: "minus.circle.fill",
                        color: .orange,
                        dishes: cookVM.almost
                    )
                }
                if !cookVM.strategic.isEmpty {
                    suggestionSection(
                        title: l10n.t("cook.strategic"),
                        icon: "brain.head.profile",
                        color: .purple,
                        dishes: cookVM.strategic
                    )
                }
            }

            // Generate button
            if !cookVM.isLoading {
                Button {
                    Task { await cookVM.loadSuggestions() }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.caption.weight(.bold))
                        Text(cookVM.hasLoaded ? l10n.t("cook.refreshSuggestions") : l10n.t("cook.generateRecipes"))
                            .font(.caption.weight(.bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    )
                }
                .buttonStyle(PressButtonStyle())
            }
        }
        .task {
            if !cookVM.hasLoaded && !cookVM.isLoading {
                await cookVM.loadSuggestions()
            }
        }
    }

    // MARK: - Suggestion Section (real AI data)

    private func suggestionSection(title: String, icon: String, color: Color, dishes: [APIClient.SuggestedDish]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(.subheadline.weight(.bold))
                Spacer()
                Text("\(dishes.count)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(color.opacity(0.7), in: Capsule())
            }

            ForEach(dishes) { dish in
                suggestionCard(dish, accentColor: color)
            }
        }
    }

    private func suggestionCard(_ dish: APIClient.SuggestedDish, accentColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Name
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(dish.dishNameLocal ?? dish.dishName)
                        .font(.subheadline.weight(.bold))
                    if let local = dish.dishNameLocal, local != dish.dishName {
                        Text(dish.dishName)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                HStack(spacing: 4) {
                    if dish.insight.usesExpiring {
                        Text("⏰").font(.caption).padding(3).background(Color.orange.opacity(0.15), in: Circle())
                    }
                    if dish.insight.highProtein {
                        Text("💪").font(.caption).padding(3).background(Color.blue.opacity(0.15), in: Circle())
                    }
                    if dish.insight.budgetFriendly {
                        Text("💰").font(.caption).padding(3).background(Color.green.opacity(0.15), in: Circle())
                    }
                }
            }

            // Nutrition
            HStack(spacing: 12) {
                nutritionMini("🔥", "\(dish.totalKcal)")
                nutritionMini("P", String(format: "%.0fg", dish.totalProteinG))
                nutritionMini("F", String(format: "%.0fg", dish.totalFatG))
                nutritionMini("C", String(format: "%.0fg", dish.totalCarbsG))
                Spacer()
                Text("🍽 \(dish.servings)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            // Ingredients
            let available = dish.ingredients.filter { $0.available }
            if !available.isEmpty {
                FlowLayout(spacing: 4) {
                    ForEach(available, id: \.slug) { ing in
                        Text(ing.name)
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                ing.expiringSoon ? Color.orange.opacity(0.2) : Color.green.opacity(0.15),
                                in: Capsule()
                            )
                            .foregroundStyle(ing.expiringSoon ? .orange : .green)
                    }
                }
            }

            // Missing
            if !dish.missingIngredients.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "cart.badge.plus")
                        .font(.caption2)
                        .foregroundStyle(.red.opacity(0.7))
                    Text(dish.missingIngredients.joined(separator: ", "))
                        .font(.caption2)
                        .foregroundStyle(.red.opacity(0.8))
                }
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(accentColor.opacity(0.3), lineWidth: 1)
        )
    }

    private func nutritionMini(_ label: String, _ value: String) -> some View {
        HStack(spacing: 2) {
            Text(label).font(.caption2.weight(.bold))
            Text(value).font(.caption2)
        }
        .foregroundStyle(.secondary)
    }
}

// MARK: - StockItemRow

struct ProductGroupRow: View {
    let group: StockViewModel.ProductGroup
    let currency: String
    let isExpanded: Bool
    let onTap: () -> Void
    let onDelete: (StockItem) -> Void
    @EnvironmentObject var l10n: LocalizationService

    var body: some View {
        VStack(spacing: 0) {
            // Header row — product summary
            HStack(spacing: 14) {
                // Product image or category icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 48, height: 48)
                    if let url = group.entries.first?.imageUrl, let imgURL = URL(string: url) {
                        AsyncImage(url: imgURL) { phase in
                            switch phase {
                            case .success(let img):
                                img.resizable().scaledToFill()
                            default:
                                Image(systemName: stockCategoryIcon(group.entries.first?.category ?? ""))
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(iconColor)
                            }
                        }
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    } else {
                        Image(systemName: stockCategoryIcon(group.entries.first?.category ?? ""))
                            .font(.body.weight(.semibold))
                            .foregroundStyle(iconColor)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(group.name)
                            .font(.subheadline.weight(.semibold))
                        if group.isExpiringSoon {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption2)
                                .foregroundStyle(.red)
                        }
                    }
                    HStack(spacing: 4) {
                        Text(fmt(group.totalQuantity))
                            .font(.caption.weight(.medium))
                        Text(group.entries.first?.unit.displayName ?? "")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if group.entryCount > 1 {
                            Text("·")
                                .foregroundStyle(.tertiary)
                            Text("\(group.entryCount) entries")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    Text(String(format: "%.2f %@", group.totalValue, currency))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.green)
                    if let days = group.soonestExpiry {
                        HStack(spacing: 5) {
                            // Expiry progress capsule
                            ExpiryProgressBar(days: days, maxDays: group.longestShelfLife)
                                .frame(width: 32, height: 5)
                            Text(days <= 1 ? l10n.t("recipes.expirestoday") : "\(days)d")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(expiryColor(days))
                        }
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
            .contentShape(Rectangle())
            .onTapGesture { onTap() }

            // Expanded — show individual entries (FIFO order)
            if isExpanded {
                VStack(spacing: 6) {
                    Divider().overlay(Color.white.opacity(0.06))

                    // Summary bar
                    HStack(spacing: 16) {
                        detailItem(icon: "tag.fill", label: l10n.t("recipes.categoryLabel"), value: group.entries.first?.category ?? "—")
                        detailItem(icon: "banknote", label: l10n.t("recipes.pricePerUnit") + " ⌀", value: String(format: "%.2f %@", group.avgPricePerUnit, currency))
                    }

                    ForEach(group.entries) { entry in
                        entryRow(entry)
                    }
                }
                .padding(.top, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(14)
        .glassCard(cornerRadius: 16)
        .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
        .overlay {
            if group.isExpiringSoon {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color.red.opacity(0.2), lineWidth: 1)
            }
        }
        .animation(.snappy(duration: 0.3), value: isExpanded)
    }

    // Single inventory entry inside the expanded group
    @ViewBuilder
    private func entryRow(_ item: StockItem) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                // Quantity × price = total
                HStack(spacing: 0) {
                    Text(fmt(item.quantity))
                        .font(.caption.weight(.bold))
                    Text(" " + item.unit.displayName + " × " )
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.2f %@", item.pricePerUnit, currency))
                        .font(.caption.weight(.medium))
                    Text(" = ")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(String(format: "%.2f %@", item.totalPrice, currency))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.green)
                }

                // Expiry progress bar + human text
                if let exp = item.expiresIn {
                    HStack(spacing: 6) {
                        ExpiryProgressBar(days: exp, maxDays: 14)
                            .frame(width: 40, height: 5)
                        Text(expiryHumanText(exp))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(expiryColor(exp))
                    }
                }
            }

            Spacer()

            Button {
                onDelete(item)
            } label: {
                Image(systemName: "trash")
                    .font(.caption2)
                    .foregroundStyle(.red.opacity(0.7))
                    .padding(6)
                    .background(Color.red.opacity(0.08), in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 10))
    }

    private func expiryHumanText(_ days: Int) -> String {
        if days <= 0 { return "⚠️ " + l10n.t("recipes.insightExpired") }
        if days == 1 { return "🔴 " + l10n.t("recipes.useToday") }
        if days <= 3 { return "🟠 \(days) " + l10n.t("recipes.daysUseFirst") }
        if days <= 7 { return "🟡 \(days) " + l10n.t("recipes.daysLeft") }
        return "🟢 \(days) " + l10n.t("recipes.days")
    }

    private func detailItem(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Text(value)
                    .font(.caption.weight(.semibold))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func fmt(_ v: Double) -> String {
        v.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", v)
            : String(format: "%.1f", v)
    }

    private var iconColor: Color {
        if group.isExpiringSoon { return .red }
        if group.isLow { return .orange }
        return .green
    }

    private func expiryColor(_ days: Int) -> Color {
        if days <= 1 { return .red }
        if days <= 3 { return .orange }
        if days <= 7 { return .yellow }
        return .green
    }
}

// MARK: - Expiry Progress Bar

struct ExpiryProgressBar: View {
    let days: Int
    let maxDays: Int
    @State private var animated = false

    private var progress: Double {
        let total = max(Double(maxDays), 1)
        let remaining = max(Double(days), 0)
        return min(remaining / total, 1.0)
    }

    private var barColor: Color {
        if days <= 1 { return .red }
        if days <= 3 { return .orange }
        if days <= 7 { return .yellow }
        return .green
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.08))
                Capsule()
                    .fill(barColor.gradient)
                    .frame(width: geo.size.width * (animated ? progress : 0))
            }
        }
        .clipShape(Capsule())
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.1)) {
                animated = true
            }
        }
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
    @EnvironmentObject var l10n: LocalizationService

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
                                Text(l10n.t("recipes.canCook"))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.green)
                            }
                        } else {
                            let missing = viewModel.missingIngredients(for: recipe)
                            HStack(spacing: 3) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                                Text("\(l10n.t("recipes.missing")) \(missing.count)")
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
                            Text("\(String(format: "%.2f %@", recipe.costPerServing, currency)) \(l10n.t("recipes.portion"))")
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
                            Text(expanded ? l10n.t("recipes.hideIngredients") : l10n.t("recipes.showIngredients"))
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
                            Text(l10n.t("recipes.cookBtn"))
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
                                Text(l10n.t("recipes.added"))
                                    .font(.caption.weight(.bold))
                            } else {
                                Image(systemName: "calendar.badge.plus")
                                    .font(.caption2)
                                Text(l10n.t("recipes.addToPlan"))
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
                            Text(l10n.t("recipes.addShopping"))
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
    @EnvironmentObject var l10n: LocalizationService

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
                            Label("\(recipe.servings) \(l10n.t("recipes.servings"))", systemImage: "person.2.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.purple)
                        }

                        // Economics
                        HStack(spacing: 20) {
                            VStack(spacing: 2) {
                                Text(String(format: "%.2f %@", recipe.estimatedCost, currency))
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(.green)
                                Text(l10n.t("recipes.totalCost"))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Divider().frame(height: 30).overlay(Color.white.opacity(0.06))
                            VStack(spacing: 2) {
                                Text(String(format: "%.2f %@", recipe.costPerServing, currency))
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(.green)
                                Text(l10n.t("recipes.portion"))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Divider().frame(height: 30).overlay(Color.white.opacity(0.06))
                            VStack(spacing: 2) {
                                let pct = viewModel.budgetPercent(for: recipe)
                                Text("\(pct)%")
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(pct <= 15 ? .green : pct <= 30 ? .orange : .red)
                                Text(l10n.t("recipes.ofBudget"))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                        HStack(spacing: 6) {
                            Image(systemName: canCookNow ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            Text(canCookNow ? l10n.t("recipes.allInStock") : "\(l10n.t("recipes.missing")) \(missing.count)")
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
                        Label(l10n.t("recipes.ingredients"), systemImage: "basket.fill")
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
                                Text(s.inStock ? "OK" : l10n.t("recipes.missing"))
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
                                    Text(l10n.t("recipes.cookNow"))
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
                                        Text(l10n.t("recipes.plan"))
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
                                    Text(l10n.t("recipes.addMissingShopping"))
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
                        Label(l10n.t("recipes.steps"), systemImage: "list.number")
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
        .environmentObject(LocalizationService())
}

// MARK: - Meal Slot Picker

struct MealSlotPicker: View {
    let recipe: Recipe
    @ObservedObject var planViewModel: PlanViewModel
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var l10n: LocalizationService

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 6) {
                Image(systemName: "calendar.badge.plus")
                    .font(.title2)
                    .foregroundStyle(.orange)
                Text(l10n.t("recipes.addToPlan"))
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
                                Text(l10n.t("recipes.replace"))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.orange)
                            } else {
                                Text(l10n.t("recipes.empty"))
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

// MARK: - Helpers

func stockCategoryIcon(_ category: String) -> String {
    let lower = category.lowercased()
    if lower.contains("veget") || lower.contains("fruit") || lower.contains("herb") { return "leaf.fill" }
    if lower.contains("meat") || lower.contains("fish") || lower.contains("seafood") { return "fork.knife" }
    if lower.contains("dairy") || lower.contains("milk") || lower.contains("cheese") { return "cup.and.saucer.fill" }
    if lower.contains("dry") || lower.contains("grain") || lower.contains("cereal") || lower.contains("pasta") { return "shippingbox.fill" }
    if lower.contains("condiment") || lower.contains("sauce") || lower.contains("oil") || lower.contains("spice") { return "drop.fill" }
    return "tray.fill"
}
