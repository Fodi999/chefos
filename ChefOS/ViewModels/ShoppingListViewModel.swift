import SwiftUI
import Combine

// MARK: - Shopping List Item

enum ShoppingItemSource: String, Codable {
    case manual
    case recipeSuggestion = "recipe_suggestion"
    case cookAnalysis = "cook_analysis"
}

struct ShoppingItem: Identifiable, Codable {
    let id: UUID
    var name: String
    var quantity: String        // e.g. "1 kg", "6 pcs"
    var note: String            // e.g. "for pasta recipe"
    var isPurchased: Bool
    var addedAt: Date
    var source: ShoppingItemSource
    var productId: String?      // catalog product id, if known

    init(name: String, quantity: String = "", note: String = "", isPurchased: Bool = false, source: ShoppingItemSource = .manual, productId: String? = nil) {
        self.id = UUID()
        self.name = name
        self.quantity = quantity
        self.note = note
        self.isPurchased = isPurchased
        self.addedAt = Date()
        self.source = source
        self.productId = productId
    }
}

// MARK: - ViewModel

@MainActor
final class ShoppingListViewModel: ObservableObject {
    @Published var items: [ShoppingItem] = []

    private let storageKey = "chefos_shopping_list"

    init() {
        load()
    }

    // MARK: - CRUD

    func add(name: String, quantity: String = "", note: String = "", source: ShoppingItemSource = .manual, productId: String? = nil) {
        // Don't add duplicates
        guard !items.contains(where: { $0.name.lowercased() == name.lowercased() && !$0.isPurchased }) else { return }
        let item = ShoppingItem(name: name, quantity: quantity, note: note, source: source, productId: productId)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            items.insert(item, at: 0)
        }
        save()
    }

    func addMultiple(_ names: [String], note: String = "") {
        for name in names {
            add(name: name, note: note)
        }
    }

    func togglePurchased(_ item: ShoppingItem) {
        guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return }
        withAnimation(.snappy(duration: 0.3)) {
            items[idx].isPurchased.toggle()
        }
        save()
    }

    func remove(_ item: ShoppingItem) {
        withAnimation(.snappy(duration: 0.3)) {
            items.removeAll { $0.id == item.id }
        }
        save()
    }

    func clearPurchased() {
        withAnimation(.snappy(duration: 0.3)) {
            items.removeAll { $0.isPurchased }
        }
        save()
    }

    var pendingCount: Int { items.filter { !$0.isPurchased }.count }
    var purchasedCount: Int { items.filter { $0.isPurchased }.count }

    var pendingItems: [ShoppingItem] { items.filter { !$0.isPurchased } }
    var purchasedItems: [ShoppingItem] { items.filter { $0.isPurchased } }

    func contains(_ name: String) -> Bool {
        items.contains { $0.name.lowercased() == name.lowercased() && !$0.isPurchased }
    }

    // MARK: - Persistence (UserDefaults)

    private func save() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let saved = try? JSONDecoder().decode([ShoppingItem].self, from: data) else { return }
        items = saved
    }
}
