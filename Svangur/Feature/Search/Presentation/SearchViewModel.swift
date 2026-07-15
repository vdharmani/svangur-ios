import SwiftUI
import Combine

@MainActor
final class SearchViewModel: ObservableObject {

    @Published var query: String = "" {
        didSet { scheduleSearch() }
    }

    @Published private(set) var state: SearchUiState = .idle
    @Published private(set) var recentSearches: [String] = []

    private let getNearbyOffersUseCase: GetNearbyOffersUseCaseProtocol
    @Published private var allOffers: [Offer] = []
    @Published private var searchTask: Task<Void, Never>?
    @Published private var hasLoadedOffers = false

    private static let recentSearchesKey = "recent_searches"
    private static let maxRecentSearches = 10

    init(getNearbyOffersUseCase: GetNearbyOffersUseCaseProtocol) {
        self.getNearbyOffersUseCase = getNearbyOffersUseCase
        self.recentSearches = Self.loadRecentSearches()
    }

    // MARK: - Lifecycle

    func onAppear() async {
        guard !hasLoadedOffers else { return }
        do throws(AppError) {
            allOffers = try await getNearbyOffersUseCase.execute()
            hasLoadedOffers = true
        } catch {
            allOffers = []
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
        performSearch(trimmed)
    }

    // MARK: - Private

    private func scheduleSearch() {
        searchTask?.cancel()
        let currentQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !currentQuery.isEmpty else {
            state = .idle
            return
        }

        guard currentQuery.count >= 2 else { return }

        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            performSearch(currentQuery)
        }
    }

    private func performSearch(_ searchText: String) {
        let lowered = searchText.lowercased()
        let mockNames = ["Pizza Palace", "Burger Joint", "Sweet Bites", "Noodle House", "Taco Town",
                         "Napoli Crust", "Firewood Pizza Co.", "Urban Bite", "Bistro 21", "Eat Street"]

        // NOTE (forced minimal fix — Offer reshape, see Feature/Offers): `Offer.category` no
        // longer exists (the backend uses a dynamic `categoryId`, not a closed enum with a
        // display-name key), so the category-name search clause was dropped. `Offer.status`
        // is no longer directly comparable to `.active` — use the separate `isActive` flag.
        let filtered = allOffers
            .filter { $0.isActive }
            .filter {
                $0.titleEn.lowercased().contains(lowered) ||
                ($0.descriptionEn ?? "").lowercased().contains(lowered)
            }

        let results = filtered.enumerated().map { idx, offer in
            offer.toSearchResult(
                restaurantName: mockNames[idx % mockNames.count],
                distance: String(format: "%.1f km", Double.random(in: 0.3...5.0))
            )
        }

        state = results.isEmpty ? .noResults(query: searchText) : .results(results)
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

// MARK: - Offer → SearchResultUi Mapper

private extension Offer {
    func toSearchResult(restaurantName: String, distance: String) -> SearchResultUi {
        let daysText: String
        if validDays.count == 7 {
            daysText = "Mon - Sun"
        } else {
            let sorted = validDays.sorted()
            if let first = sorted.first, let last = sorted.last {
                daysText = "\(first.shortName) - \(last.shortName)"
            } else {
                daysText = ""
            }
        }

        let timeRange = "\(validTimeStart.formatted24h) - \(validTimeEnd.formatted24h)"

        return SearchResultUi(
            id: id,
            restaurantName: restaurantName,
            dealTitle: titleEn,
            distanceAndTime: "\(distance) \u{2022} \(daysText) \(timeRange)",
            imageUrl: imageUrls.first
        )
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
            getNearbyOffersUseCase: FakeSearchOffersUseCase()
        )
        vm.state = state
        vm.recentSearches = recentSearches
        return vm
    }
}

private struct FakeSearchOffersUseCase: GetNearbyOffersUseCaseProtocol {
    func execute() async throws(AppError) -> [Offer] { [] }
}
