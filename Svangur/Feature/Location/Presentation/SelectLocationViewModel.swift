import SwiftUI
import Combine

@MainActor
final class SelectLocationViewModel: ObservableObject {

    /// Typing only updates the field — no live search. A lookup fires solely from
    /// `searchNow()`, triggered by the keyboard's Search button. Clearing the field cancels
    /// any in-flight search and resets to `.idle`, which removes the results and lets the
    /// Recent Searches section reappear.
    @Published var query: String = "" {
        didSet {
            guard query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  state != .idle else { return }
            searchTask?.cancel()
            state = .idle
        }
    }

    @Published private(set) var state: SelectLocationUiState = .idle
    @Published private(set) var recentSearches: [RecentLocationSearch] = []

    /// `nonisolated(unsafe)`: only ever mutated from `@MainActor` methods, except for the
    /// `cancel()` call in `deinit` — see `RegisterRestaurantViewModel.addressSearchTask` for
    /// the same pattern and rationale.
    nonisolated(unsafe) private var searchTask: Task<Void, Never>?

    private static let recentSearchesKey = "recent_location_searches"
    private static let maxRecentSearches = 5

    private let placesService: PlacesServiceProtocol

    init(placesService: PlacesServiceProtocol) {
        self.placesService = placesService
        self.recentSearches = Self.loadRecentSearches()
    }

    deinit {
        searchTask?.cancel()
    }

    // MARK: - Actions

    func selectRecent(_ item: RecentLocationSearch) {
        addToRecentSearches(item)
    }

    func selectResult(_ result: SelectLocationResultUi) {
        addToRecentSearches(RecentLocationSearch(displayName: result.displayName, placeID: result.id))
        // Populate the field with the picked location and dismiss the loader + results list.
        searchTask?.cancel()
        query = result.displayName
        state = .idle
        // Do NOT reset the Places session here — `ConfirmLocationViewModel.onAppear()` must
        // fetch this suggestion's details with the SAME session token the autocomplete search
        // used (Google bills the pair as one session). The session is reset from
        // `ConfirmLocationViewModel` once the details fetch completes.
    }

    func clearRecentSearches() {
        recentSearches = []
        Self.saveRecentSearches([])
    }

    // MARK: - Search

    /// Triggered only when the user taps the keyboard's "Search" button — never fires while
    /// typing, so exactly one API request goes out per explicit search.
    func searchNow() {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            state = .idle
            return
        }

        guard trimmed.count >= 2 else { return }

        state = .searching
        searchTask = Task { [weak self] in
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

    private func addToRecentSearches(_ item: RecentLocationSearch) {
        var searches = recentSearches.filter { $0.displayName.lowercased() != item.displayName.lowercased() }
        searches.insert(item, at: 0)
        if searches.count > Self.maxRecentSearches {
            searches = Array(searches.prefix(Self.maxRecentSearches))
        }
        recentSearches = searches
        Self.saveRecentSearches(searches)
    }

    private static func loadRecentSearches() -> [RecentLocationSearch] {
        if let data = UserDefaults.standard.data(forKey: recentSearchesKey),
           let decoded = try? JSONDecoder().decode([RecentLocationSearch].self, from: data) {
            return decoded
        }
        // Legacy format: recents were once stored as a plain string array (no place IDs).
        // Migrate them so they still show; they resolve via GPS until re-picked from search.
        if let legacy = UserDefaults.standard.stringArray(forKey: recentSearchesKey) {
            return legacy.map { RecentLocationSearch(displayName: $0, placeID: nil) }
        }
        return []
    }

    private static func saveRecentSearches(_ searches: [RecentLocationSearch]) {
        guard let data = try? JSONEncoder().encode(searches) else { return }
        UserDefaults.standard.set(data, forKey: recentSearchesKey)
    }
}

// MARK: - Preview Factory

extension SelectLocationViewModel {
    @MainActor
    static func previewInstance(
        query: String = "",
        state: SelectLocationUiState = .idle,
        recentSearches: [RecentLocationSearch] = [
            RecentLocationSearch(displayName: "Bistro 21", placeID: "1"),
            RecentLocationSearch(displayName: "Urban Bite", placeID: "2"),
            RecentLocationSearch(displayName: "Eat Street", placeID: "3")
        ]
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
