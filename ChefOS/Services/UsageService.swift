//
//  UsageService.swift
//  ChefOS
//

import Foundation
import SwiftUI
import Combine

// MARK: - Backend Client Protocol (source of truth)

/// Backend = source of truth. UserDefaults = offline cache only.
protocol UsageBackendClient {
    func fetchPurchasedActions() async throws -> Int
    func recordPurchase(actions: Int, receiptData: Data?) async throws -> Int
    func fetchDailyUsage() async throws -> DailyUsageSnapshot
    func recordAction(type: String) async throws -> UsageResponse
}

struct DailyUsageSnapshot {
    var plansUsed: Int
    var recipesUsed: Int
    var scansUsed: Int
    var optimizeUsed: Int
    var chatsUsed: Int
}

struct UsageResponse {
    var allowed: Bool
    var remaining: Int
    var purchasedActionsLeft: Int
    var warning: Bool
    var reason: String?
    var message: String?
    // Full usage snapshot from server
    var plansLeft: Int
    var recipesLeft: Int
    var scansLeft: Int
    var optimizeLeft: Int
    var chatsLeft: Int
}

/// Real backend client — calls Rust/Axum API
final class LiveUsageBackend: UsageBackendClient {
    private let api = APIClient.shared

    func fetchPurchasedActions() async throws -> Int {
        let response = try await api.getUsageToday()
        return response.purchasedActions
    }

    func recordPurchase(actions: Int, receiptData: Data?) async throws -> Int {
        let response = try await api.recordPurchase(actions: actions, receiptId: nil)
        return response.purchasedActions
    }

    func fetchDailyUsage() async throws -> DailyUsageSnapshot {
        let r = try await api.getUsageToday()
        // Convert "remaining" back to "used" for local state
        return .init(
            plansUsed: r.dailyLimits.plans - r.plansLeft,
            recipesUsed: r.dailyLimits.recipes - r.recipesLeft,
            scansUsed: r.dailyLimits.scans - r.scansLeft,
            optimizeUsed: r.dailyLimits.optimize - r.optimizeLeft,
            chatsUsed: r.dailyLimits.chats - r.chatsLeft
        )
    }

    func recordAction(type: String) async throws -> UsageResponse {
        let r = try await api.performAction(type)
        return .init(
            allowed: r.allowed,
            remaining: r.remainingFree,
            purchasedActionsLeft: r.purchasedActionsLeft,
            warning: r.warning,
            reason: r.reason,
            message: r.message,
            plansLeft: r.usage.plansLeft,
            recipesLeft: r.usage.recipesLeft,
            scansLeft: r.usage.scansLeft,
            optimizeLeft: r.usage.optimizeLeft,
            chatsLeft: r.usage.chatsLeft
        )
    }
}

/// Offline fallback — UserDefaults cache (used when no network)
final class OfflineUsageBackend: UsageBackendClient {
    func fetchPurchasedActions() async throws -> Int { UserDefaults.standard.integer(forKey: "chefos_purchased_actions") }
    func recordPurchase(actions: Int, receiptData: Data?) async throws -> Int {
        let current = UserDefaults.standard.integer(forKey: "chefos_purchased_actions")
        let newTotal = current + actions
        UserDefaults.standard.set(newTotal, forKey: "chefos_purchased_actions")
        return newTotal
    }
    func fetchDailyUsage() async throws -> DailyUsageSnapshot { .init(plansUsed: 0, recipesUsed: 0, scansUsed: 0, optimizeUsed: 0, chatsUsed: 0) }
    func recordAction(type: String) async throws -> UsageResponse {
        .init(allowed: true, remaining: 99, purchasedActionsLeft: 0, warning: false, reason: nil, message: nil,
              plansLeft: 99, recipesLeft: 99, scansLeft: 99, optimizeLeft: 99, chatsLeft: 99)
    }
}

// MARK: - Services/Usage

final class UsageService: ObservableObject {

    // MARK: - Action Costs (internal, never shown as "tokens")

    struct ActionCost {
        static let generatePlan = 5
        static let createRecipe = 3
        static let scanReceipt = 2
        static let optimizeDay = 4
        static let aiChat = 1
    }

    // MARK: - Daily Free Limits

    struct DailyLimits {
        static let plans = 2
        static let recipes = 2
        static let scans = 1
        static let optimize = 1
        static let chats = 10
    }

    // MARK: - State

    @Published var dailyPlansUsed: Int = 0
    @Published var dailyRecipesUsed: Int = 0
    @Published var dailyScansUsed: Int = 0
    @Published var dailyOptimizeUsed: Int = 0
    @Published var dailyChatsUsed: Int = 0
    @Published var purchasedActions: Int = 0
    @Published var showPaywall: Bool = false
    @Published var blockedAction: String = ""
    @Published var actionCostPreview: String = ""   // pre-action warning text
    @Published var showConfirmation: Bool = false     // confirm before costly action
    @Published var pendingAction: (() -> Void)? = nil

    // MARK: - Bonus State

    @Published var welcomeBonusGranted: Bool = false
    @Published var lastWeeklyBonus: Date? = nil

    // MARK: - Analytics

    @Published var totalGenerates: Int = 0
    @Published var totalPaywallShows: Int = 0
    @Published var totalPurchases: Int = 0

    // MARK: - Keys

    private let resetKey = "chefos_usage_reset_date"
    private let purchasedKey = "chefos_purchased_actions"
    private let welcomeBonusKey = "chefos_welcome_bonus_granted"
    private let weeklyBonusKey = "chefos_weekly_bonus_date"
    private let plansUsedKey = "chefos_daily_plans_used"
    private let recipesUsedKey = "chefos_daily_recipes_used"
    private let scansUsedKey = "chefos_daily_scans_used"
    private let optimizeUsedKey = "chefos_daily_optimize_used"
    private let chatsUsedKey = "chefos_daily_chats_used"

    // MARK: - Backend

    let backend: UsageBackendClient

    init(backend: UsageBackendClient = LiveUsageBackend()) {
        self.backend = backend
        // Load cached state
        purchasedActions = UserDefaults.standard.integer(forKey: purchasedKey)
        welcomeBonusGranted = UserDefaults.standard.bool(forKey: welcomeBonusKey)
        lastWeeklyBonus = UserDefaults.standard.object(forKey: weeklyBonusKey) as? Date

        // Load persisted daily usage (survives app restart within same day)
        dailyPlansUsed = UserDefaults.standard.integer(forKey: plansUsedKey)
        dailyRecipesUsed = UserDefaults.standard.integer(forKey: recipesUsedKey)
        dailyScansUsed = UserDefaults.standard.integer(forKey: scansUsedKey)
        dailyOptimizeUsed = UserDefaults.standard.integer(forKey: optimizeUsedKey)
        dailyChatsUsed = UserDefaults.standard.integer(forKey: chatsUsedKey)

        checkCalendarDayReset()
        checkWeeklyBonus()
        syncWithBackend()
    }

    // MARK: - Calendar Day Reset (00:00 user timezone)

    private func checkCalendarDayReset() {
        let calendar = Calendar.current

        if let lastReset = UserDefaults.standard.object(forKey: resetKey) as? Date {
            if !calendar.isDateInToday(lastReset) {
                resetDaily()
            }
        } else {
            resetDaily()
        }
    }

    private func resetDaily() {
        dailyPlansUsed = 0
        dailyRecipesUsed = 0
        dailyScansUsed = 0
        dailyOptimizeUsed = 0
        dailyChatsUsed = 0
        persistDailyUsage()
        UserDefaults.standard.set(Date(), forKey: resetKey)
    }

    private func persistDailyUsage() {
        UserDefaults.standard.set(dailyPlansUsed, forKey: plansUsedKey)
        UserDefaults.standard.set(dailyRecipesUsed, forKey: recipesUsedKey)
        UserDefaults.standard.set(dailyScansUsed, forKey: scansUsedKey)
        UserDefaults.standard.set(dailyOptimizeUsed, forKey: optimizeUsedKey)
        UserDefaults.standard.set(dailyChatsUsed, forKey: chatsUsedKey)
    }

    // MARK: - Weekly Bonus (+5 every Monday)

    private func checkWeeklyBonus() {
        let calendar = Calendar.current
        let now = Date()
        guard calendar.component(.weekday, from: now) == 2 else { return } // Monday
        if let last = lastWeeklyBonus, calendar.isDateInToday(last) { return }
        purchasedActions += 5
        lastWeeklyBonus = now
        UserDefaults.standard.set(now, forKey: weeklyBonusKey)
        savePurchasedCache()
    }

    // MARK: - Welcome Bonus (+20 on first launch)

    func grantWelcomeBonus() {
        guard !welcomeBonusGranted else { return }
        // Optimistic
        welcomeBonusGranted = true
        purchasedActions += 20
        UserDefaults.standard.set(true, forKey: welcomeBonusKey)
        savePurchasedCache()
        // Server sync
        Task { @MainActor in
            _ = try? await APIClient.shared.grantWelcomeBonus()
        }
    }

    // MARK: - Backend Sync (full state from server)

    private func syncWithBackend() {
        Task { @MainActor in
            do {
                // Pull full state from server
                let serverUsage = try await backend.fetchDailyUsage()
                let serverActions = try await backend.fetchPurchasedActions()

                self.dailyPlansUsed = serverUsage.plansUsed
                self.dailyRecipesUsed = serverUsage.recipesUsed
                self.dailyScansUsed = serverUsage.scansUsed
                self.dailyOptimizeUsed = serverUsage.optimizeUsed
                self.dailyChatsUsed = serverUsage.chatsUsed
                self.purchasedActions = serverActions

                self.persistDailyUsage()
                self.savePurchasedCache()
            } catch {
                // Offline — keep cached values
            }
        }
    }

    // MARK: - Remaining Counts (what user sees)

    var freePlansRemaining: Int { max(0, DailyLimits.plans - dailyPlansUsed) }
    var freeRecipesRemaining: Int { max(0, DailyLimits.recipes - dailyRecipesUsed) }
    var freeScansRemaining: Int { max(0, DailyLimits.scans - dailyScansUsed) }
    var freeOptimizeRemaining: Int { max(0, DailyLimits.optimize - dailyOptimizeUsed) }
    var freeChatsRemaining: Int { max(0, DailyLimits.chats - dailyChatsUsed) }

    var plansRemaining: Int {
        freePlansRemaining + (purchasedActions >= ActionCost.generatePlan ? purchasedActions / ActionCost.generatePlan : 0)
    }

    var recipesRemaining: Int {
        freeRecipesRemaining + (purchasedActions >= ActionCost.createRecipe ? purchasedActions / ActionCost.createRecipe : 0)
    }

    var scansRemaining: Int {
        freeScansRemaining + (purchasedActions >= ActionCost.scanReceipt ? purchasedActions / ActionCost.scanReceipt : 0)
    }

    var optimizeRemaining: Int {
        freeOptimizeRemaining + (purchasedActions >= ActionCost.optimizeDay ? purchasedActions / ActionCost.optimizeDay : 0)
    }

    var chatsRemaining: Int {
        freeChatsRemaining + purchasedActions
    }

    /// Total free actions left today
    var dailyFreeLeft: Int {
        freePlansRemaining + freeRecipesRemaining + freeScansRemaining + freeOptimizeRemaining + freeChatsRemaining
    }

    /// Summary for UI
    var actionsLeftToday: Int {
        dailyFreeLeft + purchasedActions
    }

    // MARK: - Soft Limit Warnings

    func softWarning(for action: String) -> String? {
        switch action {
        case "plan generation":
            if freePlansRemaining == 1 && purchasedActions < ActionCost.generatePlan {
                return "Only 1 free plan left today"
            }
        case "AI chat", "AI suggestion":
            if freeChatsRemaining <= 3 && purchasedActions < ActionCost.aiChat {
                return "Only \(freeChatsRemaining) free chats left today"
            }
        case "optimization":
            if freeOptimizeRemaining == 1 && purchasedActions < ActionCost.optimizeDay {
                return "Last free optimization today"
            }
        case "receipt scan":
            if freeScansRemaining == 1 && purchasedActions < ActionCost.scanReceipt {
                return "Last free scan today"
            }
        default: break
        }
        return nil
    }

    // MARK: - Can Perform?

    func canGeneratePlan() -> Bool {
        dailyPlansUsed < DailyLimits.plans || purchasedActions >= ActionCost.generatePlan
    }

    func canCreateRecipe() -> Bool {
        dailyRecipesUsed < DailyLimits.recipes || purchasedActions >= ActionCost.createRecipe
    }

    func canScanReceipt() -> Bool {
        dailyScansUsed < DailyLimits.scans || purchasedActions >= ActionCost.scanReceipt
    }

    func canOptimize() -> Bool {
        dailyOptimizeUsed < DailyLimits.optimize || purchasedActions >= ActionCost.optimizeDay
    }

    func canChat() -> Bool {
        dailyChatsUsed < DailyLimits.chats || purchasedActions >= ActionCost.aiChat
    }

    // MARK: - Consume (optimistic local + server sync)

    func useGeneratePlan() {
        totalGenerates += 1
        if dailyPlansUsed < DailyLimits.plans {
            dailyPlansUsed += 1
        } else {
            purchasedActions = max(0, purchasedActions - ActionCost.generatePlan)
            savePurchasedCache()
        }
        persistDailyUsage()
        syncAction("generate_plan")
    }

    func useCreateRecipe() {
        if dailyRecipesUsed < DailyLimits.recipes {
            dailyRecipesUsed += 1
        } else {
            purchasedActions = max(0, purchasedActions - ActionCost.createRecipe)
            savePurchasedCache()
        }
        persistDailyUsage()
        syncAction("create_recipe")
    }

    func useScanReceipt() {
        if dailyScansUsed < DailyLimits.scans {
            dailyScansUsed += 1
        } else {
            purchasedActions = max(0, purchasedActions - ActionCost.scanReceipt)
            savePurchasedCache()
        }
        persistDailyUsage()
        syncAction("scan_receipt")
    }

    func useOptimize() {
        if dailyOptimizeUsed < DailyLimits.optimize {
            dailyOptimizeUsed += 1
        } else {
            purchasedActions = max(0, purchasedActions - ActionCost.optimizeDay)
            savePurchasedCache()
        }
        persistDailyUsage()
        syncAction("optimize_day")
    }

    func useChat() {
        if dailyChatsUsed < DailyLimits.chats {
            dailyChatsUsed += 1
        } else {
            purchasedActions = max(0, purchasedActions - ActionCost.aiChat)
            savePurchasedCache()
        }
        persistDailyUsage()
        syncAction("ai_chat")
    }

    /// Fire-and-forget server sync after local optimistic update
    private func syncAction(_ type: String) {
        Task { @MainActor in
            do {
                let response = try await backend.recordAction(type: type)
                // Reconcile ALL state from server usage snapshot
                let limits = DailyLimits.self
                self.dailyPlansUsed = limits.plans - response.plansLeft
                self.dailyRecipesUsed = limits.recipes - response.recipesLeft
                self.dailyScansUsed = limits.scans - response.scansLeft
                self.dailyOptimizeUsed = limits.optimize - response.optimizeLeft
                self.dailyChatsUsed = limits.chats - response.chatsLeft
                self.purchasedActions = response.purchasedActionsLeft
                self.persistDailyUsage()
                self.savePurchasedCache()
            } catch {
                // Offline — local state is already updated
            }
        }
    }

    // MARK: - Purchase (server-first)

    func addPurchasedActions(_ count: Int) {
        totalPurchases += 1
        // Optimistic update
        purchasedActions += count
        savePurchasedCache()
        // Sync to backend
        Task { @MainActor in
            do {
                let serverTotal = try await backend.recordPurchase(actions: count, receiptData: nil)
                self.purchasedActions = serverTotal
                self.savePurchasedCache()
            } catch {
                // Keep optimistic value; will reconcile on next sync
            }
        }
    }

    private func savePurchasedCache() {
        UserDefaults.standard.set(purchasedActions, forKey: purchasedKey)
    }

    // MARK: - Smart Paywall Trigger (with pre-warning)

    /// Two-phase gating:
    /// 1. If allowed → show cost preview, then execute
    /// 2. If blocked → show paywall with context
    func requestAction(_ action: String, canPerform: Bool, onAllow: @escaping () -> Void) {
        if canPerform {
            // Show soft warning if running low (non-blocking)
            if let warning = softWarning(for: action) {
                actionCostPreview = warning
                // Auto-dismiss after 2s
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
                    if self?.actionCostPreview == warning {
                        withAnimation { self?.actionCostPreview = "" }
                    }
                }
            }
            onAllow()
        } else {
            totalPaywallShows += 1
            blockedAction = action
            // Pre-block message
            actionCostPreview = "You're out of free \(action)s for today"
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                showPaywall = true
            }
        }
    }

    // MARK: - Time Until Reset

    var timeUntilReset: String {
        let calendar = Calendar.current
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date())) else {
            return "midnight"
        }
        let diff = calendar.dateComponents([.hour, .minute], from: Date(), to: tomorrow)
        let h = diff.hour ?? 0
        let m = diff.minute ?? 0
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }
}

// MARK: - Store Packages

struct StorePackage: Identifiable {
    let id = UUID()
    let name: String
    let actions: Int
    let price: String
    let priceValue: Double
    let badge: String?
    let color: Color

    static let packages: [StorePackage] = [
        .init(name: "Starter", actions: 20, price: "$0.99", priceValue: 0.99, badge: nil, color: .cyan),
        .init(name: "Popular", actions: 120, price: "$4.99", priceValue: 4.99, badge: "Best value", color: .orange),
        .init(name: "Pro", actions: 300, price: "$9.99", priceValue: 9.99, badge: "Save 40%", color: .purple),
    ]
}
