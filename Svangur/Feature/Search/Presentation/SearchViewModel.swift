import SwiftUI
import Combine

@MainActor
final class SearchViewModel: ObservableObject {

    @Published var query: String = "" {
        didSet { scheduleSearch() }
    }

    @Published private(set) var state: SearchUiState = .idle
    @Published private(set) var recentSearches: [String] = []

    private let searchOffersUseCase: SearchOffersUseCaseProtocol
    private let getCurrentLocationUseCase: GetCurrentLocationUseCaseProtocol
    private var currentLocation: LocationSnapshot?

    /// `nonisolated(unsafe)`: only ever mutated from `@MainActor` methods, except for the
    /// `cancel()` call in `deinit` — see `SelectLocationViewModel.searchTask` for the same
    /// pattern and rationale.
    nonisolated(unsafe) private var searchTask: Task<Void, Never>?

    private static let recentSearchesKey = "recent_searches"
    private static let maxRecentSearches = 10

    init(
        searchOffersUseCase: SearchOffersUseCaseProtocol,
        getCurrentLocationUseCase: GetCurrentLocationUseCaseProtocol
    ) {
        self.searchOffersUseCase = searchOffersUseCase
        self.getCurrentLocationUseCase = getCurrentLocationUseCase
        self.recentSearches = Self.loadRecentSearches()
    }

    deinit {
        searchTask?.cancel()
    }

    // MARK: - Lifecycle

    func onAppear() async {
        guard currentLocation == nil else { return }
        do throws(AppError) {
            currentLocation = try await getCurrentLocationUseCase.execute()
        } catch {
            currentLocation = nil
        }
    }

    // MARK: - Actions

    func selectRecentSearch(_ text: String) {
        query = text
    }

    func clearRecentSearches() {
        recentSearches = []
        Self.saveRecentSearches([])
    }

    func submitSearch() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        addToRecentSearches(trimmed)
        searchTask?.cancel()
        state = .searching
        searchTask = Task { [weak self] in
            await self?.performSearch(trimmed)
        }
    }

    // MARK: - Private

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
            let offers = try await searchOffersUseCase.execute(
                query: searchText,
                lat: currentLocation?.latitude,
                lng: currentLocation?.longitude
            )
            // The user may have kept typing (or cleared the field) while this request was in
            // flight — only apply results that still match the current text.
            guard !Task.isCancelled, searchText == query.trimmingCharacters(in: .whitespacesAndNewlines) else { return }
            let results = offers.map { $0.toUi() }
            state = results.isEmpty ? .noResults(query: searchText) : .results(results)
        } catch {
            guard !Task.isCancelled, searchText == query.trimmingCharacters(in: .whitespacesAndNewlines) else { return }
            state = .error(message: error.displayMessage)
        }
    }

    private func addToRecentSearches(_ text: String) {
        var searches = recentSearches.filter { $0.lowercased() != text.lowercased() }
        searches.insert(text, at: 0)
        if searches.count > Self.maxRecentSearches {
            searches = Array(searches.prefix(Self.maxRecentSearches))
        }
        recentSearches = searches
        Self.saveRecentSearches(searches)
    }

    // MARK: - Persistence

    private static func loadRecentSearches() -> [String] {
        UserDefaults.standard.stringArray(forKey: recentSearchesKey) ?? []
    }

    private static func saveRecentSearches(_ searches: [String]) {
        UserDefaults.standard.set(searches, forKey: recentSearchesKey)
    }
}

// MARK: - Preview Factory

extension SearchViewModel {
    @MainActor
    static func previewInstance(
        state: SearchUiState = .idle,
        recentSearches: [String] = ["Bistro 21", "Urban Bite", "Eat Street"]
    ) -> SearchViewModel {
        let vm = SearchViewModel(
            searchOffersUseCase: FakeSearchOffersUseCase(),
            getCurrentLocationUseCase: FakeGetCurrentLocationUseCase()
        )
        vm.state = state
        vm.recentSearches = recentSearches
        return vm
    }
}

private struct FakeSearchOffersUseCase: SearchOffersUseCaseProtocol {
    func execute(query: String, lat: Double?, lng: Double?) async throws(AppError) -> [SearchOffer] { [] }
}

private struct FakeGetCurrentLocationUseCase: GetCurrentLocationUseCaseProtocol {
    func execute() async throws(AppError) -> LocationSnapshot {
        LocationSnapshot(latitude: 0, longitude: 0, displayText: "Preview")
    }
}
