import SwiftUI
import Combine

@MainActor
final class SelectLocationViewModel: ObservableObject {

    @Published var query: String = "" {
        didSet { scheduleSearch() }
    }

    @Published private(set) var state: SelectLocationUiState = .idle
    @Published private(set) var recentSearches: [String] = []

    /// `nonisolated(unsafe)`: only ever mutated from `@MainActor` methods, except for the
    /// `cancel()` call in `deinit` — see `RegisterRestaurantViewModel.addressSearchTask` for
    /// the same pattern and rationale.
    nonisolated(unsafe) private var searchTask: Task<Void, Never>?

    private static let recentSearchesKey = "recent_location_searches"
    private static let maxRecentSearches = 10

    private let placesService: PlacesServiceProtocol

    init(placesService: PlacesServiceProtocol) {
        self.placesService = placesService
        self.recentSearches = Self.loadRecentSearches()
    }

    deinit {
        searchTask?.cancel()
    }

    // MARK: - Actions

    func selectRecent(_ name: String) {
        addToRecentSearches(name)
    }

    func selectResult(_ result: SelectLocationResultUi) {
        addToRecentSearches(result.displayName)
        // Billed as part of the session that started with the autocomplete search — reset only
        // now, once the picked suggestion is on its way to `ConfirmLocationViewModel`, so the
        // next search starts a fresh Places session.
        Task { await placesService.resetSession() }
    }

    func clearRecentSearches() {
        recentSearches = []
        Self.saveRecentSearches([])
    }

    // MARK: - Search

    private func scheduleSearch() {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            state = .idle
            return
        }

        guard trimmed.count >= 2 else { return }

        state = .searching
        searchTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await self?.performSearch(trimmed)
        }
    }

    private func performSearch(_ searchText: String) async {
        do throws(AppError) {
            let suggestions = try await placesService.autocomplete(query: searchText)
            // The user may have kept typing (or cleared the field) while this request was in
            // flight — only apply results that still match the current text.
            guard !Task.isCancelled, searchText == query.trimmingCharacters(in: .whitespacesAndNewlines) else { return }
            let results = suggestions.map { SelectLocationResultUi(id: $0.id, displayName: $0.description) }
            state = results.isEmpty ? .noResults(query: searchText) : .results(results)
        } catch {
            guard !Task.isCancelled, searchText == query.trimmingCharacters(in: .whitespacesAndNewlines) else { return }
            state = .error(message: error.displayMessage)
        }
    }

    // MARK: - Recents

    private func addToRecentSearches(_ text: String) {
        var searches = recentSearches.filter { $0.lowercased() != text.lowercased() }
        searches.insert(text, at: 0)
        if searches.count > Self.maxRecentSearches {
            searches = Array(searches.prefix(Self.maxRecentSearches))
        }
        recentSearches = searches
        Self.saveRecentSearches(searches)
    }

    private static func loadRecentSearches() -> [String] {
        UserDefaults.standard.stringArray(forKey: recentSearchesKey) ?? []
    }

    private static func saveRecentSearches(_ searches: [String]) {
        UserDefaults.standard.set(searches, forKey: recentSearchesKey)
    }
}

// MARK: - Preview Factory

extension SelectLocationViewModel {
    @MainActor
    static func previewInstance(
        query: String = "",
        state: SelectLocationUiState = .idle,
        recentSearches: [String] = ["Bistro 21", "Urban Bite", "Eat Street"]
    ) -> SelectLocationViewModel {
        let vm = SelectLocationViewModel(placesService: FakePlacesService())
        vm.query = query
        vm.state = state
        vm.recentSearches = recentSearches
        return vm
    }
}

private struct FakePlacesService: PlacesServiceProtocol {
    func autocomplete(query: String) async throws(AppError) -> [PlaceSuggestion] {
        [PlaceSuggestion(id: "1", description: "\(query), Reykjavik, Iceland")]
    }
    func placeDetails(placeID: String) async throws(AppError) -> PlaceDetails {
        PlaceDetails(
            formattedAddress: "Laugavegur 1, 101 Reykjavik, Iceland",
            city: "Reykjavik",
            country: "Iceland",
            latitude: 64.1466,
            longitude: -21.9426
        )
    }
    func resetSession() async {}
}
