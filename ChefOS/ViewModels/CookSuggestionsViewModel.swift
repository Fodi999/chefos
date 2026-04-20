import SwiftUI
import Combine

@MainActor
final class CookSuggestionsViewModel: ObservableObject {
    @Published var canCook: [APIClient.SuggestedDish] = []
    @Published var almost: [APIClient.SuggestedDish] = []
    @Published var strategic: [APIClient.SuggestedDish] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var hasLoaded = false

    private let api = APIClient.shared

    func loadSuggestions() async {
        isLoading = true
        errorMessage = nil
        do {
            let response = try await api.getCookSuggestions()
            canCook = response.canCook
            almost = response.almost
            strategic = response.strategic
            hasLoaded = true
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    var isEmpty: Bool {
        canCook.isEmpty && almost.isEmpty && strategic.isEmpty
    }
}
