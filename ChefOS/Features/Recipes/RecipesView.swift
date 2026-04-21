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
    @StateObject private var shoppingVM = ShoppingListViewModel()
    @StateObject private var favVM = FavoritesViewModel()
    @State private var productActionName: String? = nil       // new product action sheet
    @State private var existingProductItem: StockItem? = nil  // existing product action sheet
    @State private var showShoppingList = false
    @State private var inventoryEditorMode: InventoryEditorMode? = nil
    @State private var showInventoryEditor = false
    @State private var selectedFavorite: FavoriteDish? = nil  // favorite detail sheet

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
            .fullScreenCover(isPresented: $showCookSuggestions) {
                CookSuggestionsSheet(vm: cookVM)
                    .environmentObject(l10n)
                    .environmentObject(regionService)
                    .environmentObject(favVM)
            }
            .sheet(item: $selectedFavorite) { fav in
                FavoriteDishDetailSheetView(fav: fav)
                    .environmentObject(l10n)
                    .environmentObject(favVM)
            }
            .sheet(isPresented: $showShoppingList) {
                ShoppingListSheet(vm: shoppingVM)
                    .environmentObject(l10n)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showInventoryEditor) {
                // Reload inventory after editor closes
                Task { await stockVM.loadInventory() }
            } content: {
                if let editorMode = inventoryEditorMode {
                    InventoryEditorSheet(mode: editorMode, stockVM: stockVM)
                        .environmentObject(l10n)
                        .environmentObject(regionService)
                        .presentationDetents([.large])
                        .presentationDragIndicator(.visible)
                }
            }
            // Action sheet for NEW product (not in inventory)
            .confirmationDialog(
                l10n.t("cook.actionTitle"),
                isPresented: Binding(
                    get: { productActionName != nil },
                    set: { if !$0 { productActionName = nil } }
                ),
                titleVisibility: .visible
            ) {
                if let name = productActionName {
                    Button(l10n.t("cook.toShoppingList")) {
                        shoppingVM.add(name: name, note: l10n.t("cook.addedFromCook"), source: .recipeSuggestion)
                        productActionName = nil
                    }
                    Button(l10n.t("cook.toInventory")) {
                        productActionName = nil
                        inventoryEditorMode = .addNew(productName: name)
                        showInventoryEditor = true
                    }
                    Button(l10n.t("general.cancel"), role: .cancel) {
                        productActionName = nil
                    }
                }
            } message: {
                if let name = productActionName {
                    Text(String(format: l10n.t("cook.actionMessage"), name))
                }
            }
            // Action sheet for EXISTING product (already in inventory)
            .confirmationDialog(
                l10n.t("inventory.existingTitle"),
                isPresented: Binding(
                    get: { existingProductItem != nil },
                    set: { if !$0 { existingProductItem = nil } }
                ),
                titleVisibility: .visible
            ) {
                if let item = existingProductItem {
                    Button(l10n.t("inventory.addBatch")) {
                        existingProductItem = nil
                        inventoryEditorMode = .addBatch(
                            productId: item.productId,
                            productName: item.name,
                            defaultUnit: item.unit.displayName
                        )
                        showInventoryEditor = true
                    }
                    Button(l10n.t("inventory.editCurrent")) {
                        existingProductItem = nil
                        inventoryEditorMode = .editExisting(item: item)
                        showInventoryEditor = true
                    }
                    Button(l10n.t("general.cancel"), role: .cancel) {
                        existingProductItem = nil
                    }
                }
            } message: {
                if let item = existingProductItem {
                    Text(String(format: l10n.t("inventory.existingMessage"), item.name))
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .addToShoppingListManual)) { notification in
                if let name = notification.userInfo?["name"] as? String {
                    shoppingVM.add(name: name, source: .manual)
                }
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
                    withAnimation(.premiumSpring) {
                        viewModel.showStock = (mode == "Stock")
                    }
                } label: {
                    HStack(spacing: .spacingS) {
                        Image(systemName: mode == "Stock" ? "shippingbox.fill" : "frying.pan.fill")
                            .font(.system(size: 12, weight: .medium))
                        Text(label)
                            .font(.system(size: 14, weight: .semibold, design: .default))
                    }
                    .foregroundStyle(isActive ? .white : .white.opacity(0.4))
                    .padding(.horizontal, .spacingL)
                    .padding(.vertical, 10)
                    .background {
                        if isActive {
                            Capsule()
                                .fill(Color.obsidianPanel.opacity(0.6))
                                .shadow(color: Color.obsidianBase.opacity(0.3), radius: 10, y: 3)
                                .overlay(Capsule().stroke(Color.white.opacity(0.05), lineWidth: 1))
                        }
                    }
                }
                .buttonStyle(PressButtonStyle())
            }
        }
        .padding(4)
        .background(.ultraThinMaterial.opacity(0.4), in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.04), lineWidth: 1))
        .frame(maxWidth: .infinity, alignment: .center)
    }

    // MARK: - Stock View

    private var stockView: some View {
        VStack(spacing: .spacingM) {
            // Action buttons row
            HStack(spacing: .spacingM) {
                // Add product button
                Button {
                    stockVM.showAddSheet = true
                } label: {
                    HStack(spacing: .spacingS) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 14))
                        Text(l10n.t("recipes.addProduct"))
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(Color.auroraBlue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.auroraBlue.opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.auroraBlue.opacity(0.2), lineWidth: 1))
                }
                .buttonStyle(PressButtonStyle())

                // Shopping list button with badge
                Button {
                    showShoppingList = true
                } label: {
                    HStack(spacing: .spacingS) {
                        Image(systemName: "cart.fill")
                            .font(.system(size: 14))
                        Text(l10n.t("cook.shoppingList"))
                            .font(.system(size: 14, weight: .semibold))
                        if shoppingVM.pendingCount > 0 {
                            Text("\(shoppingVM.pendingCount)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.amberGlow, in: Capsule())
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.obsidianPanel.opacity(0.6), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.white.opacity(0.05), lineWidth: 1))
                }
                .buttonStyle(PressButtonStyle())
            }
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
        VStack(alignment: .leading, spacing: .spacingM) {
            // Header
            HStack(spacing: .spacingS) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.auroraBlue)
                    .symbolEffect(.bounce, options: .repeating)
                Text(l10n.t("recipes.smartInsight"))
                    .premiumHeader()
                    .foregroundStyle(Color.auroraBlue)
                Spacer()
                // Action hint / badge
                if stockVM.estimatedDaysOfFood > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                        Text("~\(stockVM.estimatedDaysOfFood)d")
                    }
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.auroraBlue.opacity(0.8))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.auroraBlue.opacity(0.15), in: Capsule())
                }
            }
            .padding(.bottom, .spacingXS)
            
            // Central Metrics Dashboard
            HStack(spacing: .spacingL) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(l10n.t("recipes.insightStatus"))
                        .premiumCaption()
                    Text(insightStatusLine)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
                
                if stockVM.wasteRiskValue > 0 {
                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 1, height: 35)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(l10n.t("recipes.insightWaste"))
                            .premiumCaption()
                        Text(String(format: "%.0f %@", stockVM.wasteRiskValue, currencySymbol))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.amberGlow)
                            .lineLimit(1)
                    }
                }
                Spacer()
            }
            
            // Action button
            Button {
                showCookSuggestions = true
                Task { await cookVM.loadSuggestions() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "rays")
                    Text(l10n.t("recipes.whatToCook"))
                }
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.obsidianBase)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.auroraBlue, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(PressButtonStyle())
        }
        .padding(.spacingM)
        .glassCard(cornerRadius: 16)
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
        VStack(spacing: .spacingM) {
            if !favVM.favorites.isEmpty {
                favoritesGrouped
            } else {
                cookFavoritesEmptyState
            }
        }
    }

    private var cookFavoritesEmptyState: some View {
        VStack(spacing: .spacingL) {
            Spacer().frame(height: 40)
            Image(systemName: "heart.slash")
                .font(.system(size: 52))
                .foregroundStyle(Color.auroraBlue.opacity(0.3))
            VStack(spacing: .spacingS) {
                Text(l10n.t("cook.noFavorites"))
                    .premiumHeader()
                    .foregroundStyle(.white)
                Text(l10n.t("cook.noFavoritesHint"))
                    .premiumCaption()
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            Spacer().frame(height: 40)
        }
    }

    // MARK: - Cook State 1: Empty Inventory

    private var cookEmptyState: some View {
        VStack(spacing: .spacingL) {
            Spacer().frame(height: 20)

            Image(systemName: "refrigerator")
                .font(.system(size: 56))
                .foregroundStyle(Color.auroraBlue.opacity(0.3))
                .symbolEffect(.pulse, options: .repeating)

            VStack(spacing: .spacingS) {
                Text(l10n.t("cook.noProducts"))
                    .premiumHeader()
                    .foregroundStyle(.white)
                Text(l10n.t("cook.noProductsHint"))
                    .premiumCaption()
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }

            VStack(spacing: 10) {
                Button {
                    withAnimation(.premiumSpring) {
                        viewModel.showStock = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        stockVM.showAddSheet = true
                    }
                } label: {
                    HStack(spacing: .spacingS) {
                        Image(systemName: "plus.circle.fill")
                            .font(.body)
                        Text(l10n.t("cook.addProducts"))
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(Color.obsidianBase)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.auroraBlue, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(PressButtonStyle())
            }

            // Hint
            HStack(spacing: .spacingS) {
                Image(systemName: "lightbulb.fill")
                    .font(.caption)
                    .foregroundStyle(Color.auroraBlue)
                Text(l10n.t("cook.addHint"))
                    .premiumCaption()
                    .foregroundStyle(Color.auroraBlue)
            }
            .padding(12)
            .background(Color.auroraBlue.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            Spacer().frame(height: 20)
        }
    }

    // MARK: - Cook State 2: Insufficient Products

    private var cookInsufficientState: some View {
        VStack(spacing: .spacingM) {
            // What you have
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "shippingbox.fill")
                        .font(.caption)
                        .foregroundStyle(Color.auroraBlue)
                    Text(l10n.t("cook.youHave"))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.auroraBlue)
                        .textCase(.uppercase)
                }

                FlowLayout(spacing: 6) {
                    ForEach(stockVM.items, id: \.id) { item in
                        HStack(spacing: 4) {
                            Text(StockViewModel.categoryEmoji(item.category))
                                .font(.caption)
                            Text(item.name)
                                .font(.system(size: 13, weight: .medium))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.obsidianBase, in: Capsule())
                        .foregroundStyle(.white)
                    }
                }
            }
            .padding(.spacingM)
            .glassCard(cornerRadius: 16)

            // 🧠 Smart analysis — WHY not enough
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.auroraBlue)
                    Text(l10n.t("cook.analysis"))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.auroraBlue)
                        .textCase(.uppercase)
                }

                // What's missing
                if !stockVM.hasProtein {
                    analysisRow(icon: "xmark.circle.fill", color: Color.amberGlow, text: l10n.t("cook.noProtein"))
                } else {
                    analysisRow(icon: "checkmark.circle.fill", color: Color.auroraBlue, text: l10n.t("cook.hasProtein"))
                }
                if !stockVM.hasBase {
                    analysisRow(icon: "xmark.circle.fill", color: Color.amberGlow, text: l10n.t("cook.noBase"))
                } else {
                    analysisRow(icon: "checkmark.circle.fill", color: Color.auroraBlue, text: l10n.t("cook.hasBase"))
                }
                if !stockVM.hasVegetables {
                    analysisRow(icon: "xmark.circle.fill", color: Color.amberGlow, text: l10n.t("cook.noVegetable"))
                } else {
                    analysisRow(icon: "checkmark.circle.fill", color: Color.auroraBlue, text: l10n.t("cook.hasVegetable"))
                }

                // Conclusion
                let missingCount = stockVM.missingCategories.count
                HStack(spacing: 8) {
                    Image(systemName: missingCount > 1 ? "exclamationmark.triangle.fill" : "info.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(missingCount > 1 ? Color.amberGlow : Color.auroraBlue)
                    Text(missingCount > 1 ? l10n.t("cook.cantCookFull") : l10n.t("cook.almostThere"))
                        .premiumCaption()
                        .foregroundStyle(.white)
                }
                .padding(.top, 4)
            }
            .padding(.spacingM)
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
                HStack(spacing: .spacingS) {
                    Image(systemName: "sparkles")
                        .font(.caption.weight(.bold))
                    Text(l10n.t("cook.tryAnyway"))
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(Color.obsidianBase)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.auroraBlue, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(PressButtonStyle())

            // Browse catalog
            Button {
                withAnimation(.premiumSpring) {
                    viewModel.showStock = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    stockVM.showAddSheet = true
                }
            } label: {
                HStack(spacing: .spacingS) {
                    Image(systemName: "plus.circle.fill")
                    Text(l10n.t("cook.browseCatalog"))
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(Color.auroraBlue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.obsidianPanel.opacity(0.6), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.white.opacity(0.05), lineWidth: 1))
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
        let inList = shoppingVM.contains(query)
        let existingItem = stockVM.items.first { $0.name.lowercased().contains(query.lowercased()) }
        let inInventory = existingItem != nil

        let iconName: String = inList ? "checkmark" : (inInventory ? "tray.fill" : "plus")
        let fgColor: Color = inList ? Color.auroraBlue : (inInventory ? Color.white : Color.white.opacity(0.8))
        let borderColor: Color = inList ? Color.auroraBlue.opacity(0.5) : (inInventory ? Color.white.opacity(0.4) : Color.white.opacity(0.2))
        let bgColor: Color = inList ? Color.auroraBlue.opacity(0.15) : (inInventory ? Color.white.opacity(0.1) : .clear)

        return Button {
            if inList {
                // noop
            } else if let existing = existingItem {
                existingProductItem = existing
            } else {
                productActionName = label
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: iconName)
                    .font(.system(size: 9, weight: .bold))
                Text(label)
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(fgColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .strokeBorder(borderColor, lineWidth: 1)
                    .background(Capsule().fill(bgColor))
            )
        }
        .buttonStyle(PressButtonStyle())
        .disabled(inList)
    }

    // MARK: - Cook State 3: Ready (3+ products)

    private var cookReadyState: some View {
        VStack(spacing: .spacingM) {
            // Inventory summary chip
            HStack(spacing: .spacingS) {
                Image(systemName: "sparkles")
                    .foregroundStyle(Color.auroraBlue)
                Text(l10n.t("recipes.basedOnStock"))
                    .font(.subheadline.weight(.bold))
                Spacer()
                Text("\(stockVM.items.count) " + l10n.t("recipes.items").lowercased())
                    .premiumCaption()
                    .foregroundStyle(.secondary)
            }

            // Available ingredients
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "leaf.fill")
                        .font(.caption)
                        .foregroundStyle(Color.auroraBlue)
                    Text(l10n.t("cook.yourIngredients"))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.auroraBlue)
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
                        .background(Color.auroraBlue.opacity(0.12), in: Capsule())
                        .foregroundStyle(Color.auroraBlue)
                    }
                    if stockVM.items.count > 12 {
                        Text("+\(stockVM.items.count - 12)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Color.white.opacity(0.06), in: Capsule())
                    }
                }
            }
            .padding(.spacingM)
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
    }

    // MARK: - Favorites Grouped by Category

    private var favoritesGrouped: some View {
        let grouped = Dictionary(grouping: favVM.favorites, by: \.dishType)
        let sortedKeys = grouped.keys.sorted()

        return VStack(spacing: 16) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: "heart.fill")
                    .foregroundStyle(.pink)
                Text(l10n.t("cook.favorites"))
                    .font(.headline.weight(.bold))
                Spacer()
                Text("\(favVM.favorites.count)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.pink.opacity(0.7), in: Capsule())
            }

            ForEach(sortedKeys, id: \.self) { category in
                if let dishes = grouped[category] {
                    favoriteCategorySection(category: category, dishes: dishes)
                        .staggerIn(appeared: appeared, delay: 0.02)
                }
            }
        }
    }

    private func favoriteCategorySection(category: String, dishes: [FavoriteDish]) -> some View {
        let color = categoryColor(category)
        let icon = categoryIcon(category)

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(localizedDishType(category))
                    .font(.subheadline.weight(.bold))
                Spacer()
                Text("\(dishes.count)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(color.opacity(0.7), in: Capsule())
            }

            ForEach(dishes) { fav in
                favoriteDishCard(fav, accentColor: color)
            }
        }
    }

    private func favoriteDishCard(_ fav: FavoriteDish, accentColor: Color) -> some View {
        let isExpanded = expandedItems.contains(fav.dishName)

        return VStack(alignment: .leading, spacing: 0) {
            // MARK: Header (always visible)
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(fav.displayName)
                        .font(.subheadline.weight(.bold))
                    if let local = fav.dishNameLocal, local != fav.displayName {
                        Text(local)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                HStack(spacing: 8) {
                    // Insights badges
                    if fav.insight.usesExpiring { Text("⏰").font(.caption2) }
                    if fav.insight.highProtein  { Text("💪").font(.caption2) }
                    if fav.insight.budgetFriendly { Text("💰").font(.caption2) }
                    Text(localizedComplexity(fav.complexity))
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(accentColor.opacity(0.15), in: Capsule())
                        .foregroundStyle(accentColor)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            // MARK: Expanded content
            if isExpanded {
                VStack(alignment: .leading, spacing: 14) {
                    Divider().padding(.top, 10)

                    // Nutrition per serving + total
                    VStack(alignment: .leading, spacing: 6) {
                        Text(l10n.t("cook.perServing"))
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        HStack(spacing: 14) {
                            nutritionMini("🔥", "\(fav.perServingKcal) kcal")
                            nutritionMini("P", String(format: "%.0fg", fav.perServingProteinG))
                            nutritionMini("F", String(format: "%.0fg", fav.perServingFatG))
                            nutritionMini("C", String(format: "%.0fg", fav.perServingCarbsG))
                            Spacer()
                            Text("🍽 \(fav.servings)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Tags + allergens
                    if !fav.tags.isEmpty || !fav.allergens.isEmpty {
                        FlowLayout(spacing: 4) {
                            ForEach(fav.tags, id: \.self) { tag in
                                Label {
                                    Text(favTagLocalized(tag))
                                        .font(.caption2)
                                } icon: {
                                    Image(systemName: favTagIcon(tag)).font(.system(size: 8))
                                }
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(accentColor.opacity(0.1), in: Capsule())
                                .foregroundStyle(accentColor)
                            }
                            ForEach(fav.allergens, id: \.self) { a in
                                Text("⚠️ \(favAllergenLocalized(a))")
                                    .font(.caption2)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 2)
                                    .background(Color.orange.opacity(0.12), in: Capsule())
                                    .foregroundStyle(.orange)
                            }
                        }
                    }

                    // Ingredients with grams
                    if !fav.ingredients.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(l10n.t("cook.ingredients"))
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                            FlowLayout(spacing: 4) {
                                ForEach(fav.ingredients, id: \.slug) { ing in
                                    HStack(spacing: 3) {
                                        Text(ing.name)
                                        if ing.grossG > 0 {
                                            Text(ing.grossG.truncatingRemainder(dividingBy: 1) == 0
                                                 ? "\(Int(ing.grossG))g"
                                                 : String(format: "%.1fg", ing.grossG))
                                            .foregroundStyle(.secondary)
                                        }
                                    }
                                    .font(.caption2)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(
                                        ing.available
                                            ? (ing.expiringSoon ? Color.orange.opacity(0.15) : accentColor.opacity(0.12))
                                            : Color.red.opacity(0.1),
                                        in: Capsule()
                                    )
                                    .foregroundStyle(
                                        ing.available
                                            ? (ing.expiringSoon ? .orange : accentColor)
                                            : .red
                                    )
                                }
                            }
                        }
                    }

                    // Missing ingredients
                    if !fav.missingIngredients.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "cart.badge.plus")
                                .font(.caption2)
                                .foregroundStyle(.red.opacity(0.7))
                            Text(fav.missingIngredients.joined(separator: ", "))
                                .font(.caption2)
                                .foregroundStyle(.red.opacity(0.8))
                        }
                    }

                    // Steps
                    VStack(alignment: .leading, spacing: 6) {
                        Text(l10n.t("cook.steps"))
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        if fav.steps.isEmpty {
                            HStack(spacing: 6) {
                                Image(systemName: "info.circle")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text(l10n.t("cook.stepsNotAvailable"))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            ForEach(fav.steps, id: \.step) { s in
                                HStack(alignment: .top, spacing: 8) {
                                    Text("\(s.step)")
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(.white)
                                        .frame(width: 18, height: 18)
                                        .background(accentColor.opacity(0.7), in: Circle())
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(s.text)
                                            .font(.caption2)
                                        HStack(spacing: 8) {
                                            if let t = s.timeMin {
                                                Label("\(t) min", systemImage: "clock")
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                            }
                                            if let temp = s.tempC {
                                                Label("\(temp)°C", systemImage: "thermometer")
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                        if let tip = s.tip {
                                            Text("💡 \(tip)")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                                .italic()
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Warnings
                    if !fav.warnings.isEmpty {
                        ForEach(fav.warnings, id: \.self) { w in
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                                Text(w).font(.caption2).foregroundStyle(.orange)
                            }
                        }
                    }

                    // Insight reasons
                    if !fav.insight.reasons.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(fav.insight.reasons, id: \.self) { r in
                                HStack(spacing: 6) {
                                    Image(systemName: "sparkles")
                                        .font(.caption2)
                                        .foregroundStyle(accentColor)
                                    Text(favReasonLocalized(r)).font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }

                    // Open full recipe
                    Button {
                        selectedFavorite = fav
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "book.fill")
                                .font(.caption)
                            Text(l10n.t("cook.openRecipe"))
                                .font(.caption.weight(.semibold))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.tertiary)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                        .background(accentColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(accentColor.opacity(0.25), lineWidth: 1)
                        )
                    }
                    .buttonStyle(PressButtonStyle())

                    // Remove from favorites
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            expandedItems.remove(fav.dishName)
                            if let idx = favVM.favorites.firstIndex(where: { $0.dishName == fav.dishName }) {
                                favVM.remove(at: IndexSet(integer: idx))
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "heart.slash.fill")
                                .font(.caption)
                            Text(l10n.t("cook.removeFromFavorites"))
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(.pink.opacity(0.8))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.pink.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(PressButtonStyle())
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isExpanded ? accentColor.opacity(0.5) : accentColor.opacity(0.2), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                if isExpanded {
                    expandedItems.remove(fav.dishName)
                } else {
                    expandedItems.insert(fav.dishName)
                }
            }
        }
    }

    private func categoryColor(_ type: String) -> Color {
        switch type {
        case "soup": return .cyan
        case "stew": return .orange
        case "salad": return .green
        case "grill": return .red
        case "pasta": return .yellow
        case "stir-fry", "stir_fry": return .orange
        default: return .pink
        }
    }

    private func categoryIcon(_ type: String) -> String {
        switch type {
        case "soup": return "drop.fill"
        case "stew": return "flame.fill"
        case "salad": return "leaf.fill"
        case "grill": return "flame"
        case "pasta": return "fork.knife"
        case "stir-fry", "stir_fry": return "frying.pan.fill"
        default: return "fork.knife.circle"
        }
    }

    private func localizedDishType(_ type: String) -> String {
        l10n.t("dishType.\(type)")
            .replacingOccurrences(of: "dishType.", with: "") // fallback: strip prefix if key missing
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }

    private func localizedComplexity(_ c: String) -> String {
        l10n.t("complexity.\(c)")
            .replacingOccurrences(of: "complexity.", with: "")
            .capitalized
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
                    .onTapGesture {
                        cookVM.selectedDish = dish
                    }
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

    // MARK: - Tag / Allergen / Reason localization helpers

    private func favTagLocalized(_ tag: String) -> String {
        let key = "tag.\(tag)"
        let result = l10n.t(key)
        return result == key ? tag.replacingOccurrences(of: "_", with: " ").capitalized : result
    }

    private func favTagIcon(_ tag: String) -> String {
        switch tag {
        case "uses_expiring_ingredients": return "clock.badge.exclamationmark"
        case "high_protein":              return "bolt.fill"
        case "all_ingredients_available": return "checkmark.circle.fill"
        case "budget_friendly":           return "dollarsign.circle.fill"
        case "low_calorie":               return "flame"
        case "high_calorie":              return "flame.fill"
        case "vegetarian":                return "leaf.fill"
        case "vegan":                     return "leaf"
        case "gluten_free":               return "xmark.circle"
        case "dairy_free":                return "drop.triangle"
        case "quick":                     return "hare.fill"
        case "seasonal":                  return "sun.max.fill"
        case "spicy":                     return "thermometer.high"
        case "high_fiber":                return "chart.bar.fill"
        case "low_carb":                  return "minus.circle"
        default:                          return "tag"
        }
    }

    private func favAllergenLocalized(_ allergen: String) -> String {
        let key = "allergen.\(allergen.lowercased())"
        let result = l10n.t(key)
        return result == key ? allergen.capitalized : result
    }

    private func favReasonLocalized(_ reason: String) -> String {
        switch reason {
        case "uses_expiring_ingredients": return l10n.t("cook.reason.expiring")
        case "high_protein":             return l10n.t("cook.reason.protein")
        case "all_ingredients_available":return l10n.t("cook.reason.allAvailable")
        case "budget_friendly":          return l10n.t("cook.reason.budget")
        case "fits_goal":                return l10n.t("cook.reason.fitsGoal")
        case "uses_inventory":           return l10n.t("cook.reason.usesInventory")
        default: return reason.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }
}

