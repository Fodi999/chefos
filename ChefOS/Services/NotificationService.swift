//
//  NotificationService.swift
//  ChefOS — Services
//
//  Local push notifications for expiring inventory + low stock.
//  iOS 2026 approach: UNUserNotificationCenter + category actions, no server needed.
//

import Foundation
import UserNotifications
import UIKit
import Combine

@MainActor
final class NotificationService: NSObject, ObservableObject {

    static let shared = NotificationService()

    // MARK: - Preferences (persisted in UserDefaults)

    @Published var isAuthorized: Bool = false

    @Published var expiryEnabled: Bool {
        didSet { UserDefaults.standard.set(expiryEnabled, forKey: Keys.expiryEnabled) }
    }

    @Published var lowStockEnabled: Bool {
        didSet { UserDefaults.standard.set(lowStockEnabled, forKey: Keys.lowStockEnabled) }
    }

    /// Hour of day (0–23) for daily expiry digest — default 9am.
    @Published var dailyHour: Int {
        didSet { UserDefaults.standard.set(dailyHour, forKey: Keys.dailyHour) }
    }

    private enum Keys {
        static let expiryEnabled    = "notif.expiryEnabled"
        static let lowStockEnabled  = "notif.lowStockEnabled"
        static let dailyHour        = "notif.dailyHour"
    }

    private enum Ident {
        static let categoryExpiry = "CHEFOS_EXPIRY"
        static let categoryLow    = "CHEFOS_LOW_STOCK"
        static let prefixExpiry   = "expiry."
        static let prefixLow      = "lowstock."
        static let actionView     = "ACTION_VIEW"
        static let actionSnooze   = "ACTION_SNOOZE"
    }

    // MARK: - Init

    private override init() {
        // Default ON for both — aligns with user's request.
        let def = UserDefaults.standard
        if def.object(forKey: Keys.expiryEnabled) == nil { def.set(true, forKey: Keys.expiryEnabled) }
        if def.object(forKey: Keys.lowStockEnabled) == nil { def.set(true, forKey: Keys.lowStockEnabled) }
        if def.object(forKey: Keys.dailyHour) == nil { def.set(9, forKey: Keys.dailyHour) }

        self.expiryEnabled   = def.bool(forKey: Keys.expiryEnabled)
        self.lowStockEnabled = def.bool(forKey: Keys.lowStockEnabled)
        self.dailyHour       = def.integer(forKey: Keys.dailyHour)

        super.init()

        UNUserNotificationCenter.current().delegate = self
        registerCategories()
        Task { await refreshAuthorization() }
    }

    // MARK: - Authorization

    /// Ask the user for notification permission. Safe to call multiple times.
    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            self.isAuthorized = granted
            return granted
        } catch {
            self.isAuthorized = false
            return false
        }
    }

    func refreshAuthorization() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        self.isAuthorized = (settings.authorizationStatus == .authorized
                            || settings.authorizationStatus == .provisional
                            || settings.authorizationStatus == .ephemeral)
    }

    // MARK: - Categories & Actions

    private func registerCategories() {
        let view = UNNotificationAction(
            identifier: Ident.actionView,
            title: "Open",
            options: [.foreground]
        )
        let snooze = UNNotificationAction(
            identifier: Ident.actionSnooze,
            title: "Snooze 1 day",
            options: []
        )
        let expiryCat = UNNotificationCategory(
            identifier: Ident.categoryExpiry,
            actions: [view, snooze],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        let lowCat = UNNotificationCategory(
            identifier: Ident.categoryLow,
            actions: [view],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        UNUserNotificationCenter.current().setNotificationCategories([expiryCat, lowCat])
    }

    // MARK: - Public API — reschedule for the current inventory

    /// Cancels all expiry + low-stock notifications and schedules fresh ones
    /// based on the provided items. Call this after inventory load / add /
    /// delete / update.
    func rescheduleInventoryNotifications(items: [StockItem]) async {
        // Always wipe our managed identifiers first so stale reminders
        // (e.g. for deleted products) disappear.
        let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
        let managed = pending.filter {
            $0.identifier.hasPrefix(Ident.prefixExpiry) ||
            $0.identifier.hasPrefix(Ident.prefixLow)
        }
        if !managed.isEmpty {
            UNUserNotificationCenter.current()
                .removePendingNotificationRequests(withIdentifiers: managed.map(\.identifier))
        }

        guard isAuthorized else { return }

        if expiryEnabled {
            scheduleExpiryReminders(for: items)
        }
        if lowStockEnabled {
            scheduleLowStockReminders(for: items)
        }

        // Keep a low-noise daily digest at the user's preferred hour.
        if expiryEnabled {
            scheduleDailyDigest(items: items)
        }
    }

    /// Clear every managed notification — useful on logout.
    func cancelAll() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        UIApplication.shared.applicationIconBadgeNumber = 0
    }

    // MARK: - Scheduling — Expiry

    /// Per-product reminders at 3 days, 1 day, and on the expiry day itself.
    /// Fires at the user's preferred hour so it doesn't wake them up.
    private func scheduleExpiryReminders(for items: [StockItem]) {
        let cal = Calendar.current
        let now = Date()

        for item in items {
            guard let expiresAt = item.expiresAt else { continue }

            let offsets: [(days: Int, title: String, body: String)] = [
                (3, "Expiring soon",    "\(item.name) expires in 3 days — use it first."),
                (1, "Expires tomorrow", "\(item.name) expires tomorrow."),
                (0, "Expires today",    "\(item.name) expires today. Cook or it'll go to waste.")
            ]

            for offset in offsets {
                guard let triggerDate = cal.date(byAdding: .day, value: -offset.days, to: expiresAt) else { continue }
                // Move the reminder to the user's preferred hour on that day.
                var comps = cal.dateComponents([.year, .month, .day], from: triggerDate)
                comps.hour = dailyHour
                comps.minute = 0
                guard let fire = cal.date(from: comps), fire > now else { continue }

                let content = UNMutableNotificationContent()
                content.title = offset.title
                content.body  = offset.body
                content.sound = .default
                content.categoryIdentifier = Ident.categoryExpiry
                content.userInfo = [
                    "kind": "expiry",
                    "productId": item.productId,
                    "expiresAt": ISO8601DateFormatter().string(from: expiresAt)
                ]
                content.threadIdentifier = "expiry-\(item.productId)"

                let trigger = UNCalendarNotificationTrigger(
                    dateMatching: cal.dateComponents([.year, .month, .day, .hour, .minute], from: fire),
                    repeats: false
                )
                let id = "\(Ident.prefixExpiry)\(item.backendId).\(offset.days)"
                let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
                UNUserNotificationCenter.current().add(request)
            }
        }
    }

    // MARK: - Scheduling — Low stock

    /// Immediate (next-minute) one-shot for any product that's currently low —
    /// iOS throttles identical repeated fires so we only ever have one per
    /// product at a time.
    private func scheduleLowStockReminders(for items: [StockItem]) {
        let lowItems = items.filter { $0.isLow && $0.quantity > 0 }
        guard !lowItems.isEmpty else { return }

        // Group into a single digest if more than one — avoids notification spam.
        if lowItems.count == 1, let item = lowItems.first {
            scheduleLowStockSingle(item)
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Running low"
        content.body  = "\(lowItems.count) items are almost out: \(lowItems.prefix(3).map(\.name).joined(separator: ", "))\(lowItems.count > 3 ? "…" : "")"
        content.sound = .default
        content.categoryIdentifier = Ident.categoryLow
        content.userInfo = ["kind": "lowStock"]
        content.threadIdentifier = "lowstock"

        // Fire 10 minutes from now so it doesn't overlap the user's current
        // "just added" session.
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 10 * 60, repeats: false)
        let request = UNNotificationRequest(
            identifier: "\(Ident.prefixLow)digest",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func scheduleLowStockSingle(_ item: StockItem) {
        let content = UNMutableNotificationContent()
        content.title = "Running low"
        content.body  = "\(item.name) is almost out (\(String(format: "%.1f", item.quantity)) \(item.unit.rawValue.lowercased()) left)."
        content.sound = .default
        content.categoryIdentifier = Ident.categoryLow
        content.userInfo = ["kind": "lowStock", "productId": item.productId]
        content.threadIdentifier = "lowstock"

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 10 * 60, repeats: false)
        let request = UNNotificationRequest(
            identifier: "\(Ident.prefixLow)\(item.backendId)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Daily digest — "what expires soon today"

    private func scheduleDailyDigest(items: [StockItem]) {
        // Find everything expiring in the next 3 days.
        let expiringSoon = items
            .compactMap { item -> (StockItem, Int)? in
                guard let days = item.expiresIn else { return nil }
                return (days >= 0 && days <= 3) ? (item, days) : nil
            }
        guard !expiringSoon.isEmpty else { return }

        let content = UNMutableNotificationContent()
        content.title = "Today's kitchen priority"
        let names = expiringSoon.prefix(3).map(\.0.name).joined(separator: ", ")
        content.body = "\(expiringSoon.count) item\(expiringSoon.count == 1 ? "" : "s") need attention: \(names)\(expiringSoon.count > 3 ? "…" : "")"
        content.sound = .default
        content.categoryIdentifier = Ident.categoryExpiry
        content.userInfo = ["kind": "digest"]
        content.threadIdentifier = "digest"

        var comps = DateComponents()
        comps.hour = dailyHour
        comps.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)

        let request = UNNotificationRequest(
            identifier: "\(Ident.prefixExpiry)digest",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }
}

// MARK: - Foreground presentation

extension NotificationService: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge, .list]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let action = response.actionIdentifier
        let info = response.notification.request.content.userInfo

        // Snooze: reschedule +24h with same content.
        if action == Ident.actionSnooze {
            let original = response.notification.request
            let content = original.content.mutableCopy() as? UNMutableNotificationContent
                ?? UNMutableNotificationContent()
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 24 * 60 * 60, repeats: false)
            let retry = UNNotificationRequest(
                identifier: original.identifier + ".snoozed",
                content: content,
                trigger: trigger
            )
            try? await center.add(retry)
            return
        }

        // Open Stock tab on tap / "View".
        await MainActor.run {
            if let kind = info["kind"] as? String {
                NotificationCenter.default.post(
                    name: .chefosDidTapStockNotification,
                    object: nil,
                    userInfo: ["kind": kind, "productId": info["productId"] as? String ?? ""]
                )
            }
        }
    }
}

// MARK: - App-level events

extension Notification.Name {
    /// Posted when the user taps an expiry / low-stock notification.
    /// Observers (MainTabView) can switch to the Recipes/Stock tab.
    static let chefosDidTapStockNotification = Notification.Name("chefos.didTapStockNotification")
}
