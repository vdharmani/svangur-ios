import SwiftUI

@MainActor
@Observable
final class SelectLocationViewModel {

    var query: String = "" {
        didSet { scheduleSearch() }
    }

    private(set) var state: SelectLocationUiState = .idle
    private(set) var recentSearches: [String] = []

    private var searchTask: Task<Void, Never>?

    private static let recentSearchesKey = "recent_location_searches"
    private static let maxRecentSearches = 10

    // Mock catalogue until a Places backend is wired in. The names match the
    // Figma example data plus a handful of extras so search returns something.
    private static let mockLocations: [String] = [
        "Bistro 21",
        "Urban Bite",
        "Eat Street",
        "Napoli Crust",
        "Firewood Pizza Co.",
        "Sweet Bites",
        "Noodle House",
        "Taco Town",
        "Pizza Palace",
        "Burger Joint"
    ]

    init() {
        self.recentSearches = Self.loadRecentSearches()
    }

    // MARK: - Actions

    func selectRecent(_ name: String) {
        addToRecentSearches(name)
    }

    func selectResult(_ result: SelectLocationResultUi) {
        addToRecentSearches(result.displayName)
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

        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            performSearch(trimmed)
        }
    }

    private func performSearch(_ searchText: String) {
        let lowered = searchText.lowercased()
        let matches = Self.mockLocations.filter { $0.lowercased().contains(lowered) }
        let results = matches.map { SelectLocationResultUi(id: $0, displayName: $0) }
        state = results.isEmpty ? .noResults(query: searchText) : .results(results)
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
        let vm = SelectLocationViewModel()
        vm.query = query
        vm.state = state
        vm.recentSearches = recentSearches
        return vm
    }
}
