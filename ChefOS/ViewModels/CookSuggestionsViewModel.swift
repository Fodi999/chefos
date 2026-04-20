import SwiftUI
import Combine

@MainActor
final class CookSuggestionsViewModel: ObservableObject {
    @Published var inventoryInsight: APIClient.InventoryInsight?
    @Published var canCook: [APIClient.SuggestedDish] = []
    @Published var almost: [APIClient.SuggestedDish] = []
    @Published var strategic: [APIClient.SuggestedDish] = []
    @Published var unlockSuggestions: APIClient.UnlockSuggestions?
    @Published var personalization: APIClient.PersonalizationInfo?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var hasLoaded = false
    @Published var selectedDish: APIClient.SuggestedDish?

    private let api = APIClient.shared

    func loadSuggestions() async {
        isLoading = true
        errorMessage = nil
        do {
            let response = try await api.getCookSuggestions()
            inventoryInsight = response.inventoryInsight
            canCook = response.canCook
            almost = response.almost
            strategic = response.strategic
            unlockSuggestions = response.suggestions
            personalization = response.personalization
            hasLoaded = true
            print("🧠 VM loaded: canCook=\(canCook.count), almost=\(almost.count), strategic=\(strategic.count), personalized=\(personalization?.personalized ?? false)")
        } catch {
            errorMessage = error.localizedDescription
            print("🔴 VM error: \(error)")
        }
        isLoading = false
    }

    var isEmpty: Bool {
        canCook.isEmpty && almost.isEmpty && strategic.isEmpty
    }
}
