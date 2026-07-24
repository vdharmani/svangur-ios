import SwiftUI
import Combine

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published private(set) var state: DashboardUiState = .idle
    @Published private(set) var profile: RestaurantProfileUi?
    @Published private(set) var isLoadingMore = false
    @Published private(set) var hasNextPage = false
    @Published var offerIdToDelete: Int64?

    /// Transient error from a *failed action* (currently: delete) taken while the offers list
    /// was already loaded and visible. Kept separate from `state` so a delete failure surfaces
    /// as a small banner (via `SvErrorBanner`) instead of clobbering the loaded list with the
    /// full-screen `.error` state — the previous behavior wiped out the user's offers list just
    /// because one delete failed. Cleared at the start of the next delete attempt.
    @Published private(set) var actionErrorMessage: String?

    private var currentPage = 1
    private let pageSize = 20
    private var currentLang: String = AppLanguage.english.rawValue

    private let getMyOffersUseCase: GetMyOffersUseCaseProtocol
    private let deleteOfferUseCase: DeleteOfferUseCaseProtocol
    private let getRestaurantProfileUseCase: GetRestaurantProfileUseCaseProtocol

    init(
        getMyOffersUseCase: GetMyOffersUseCaseProtocol,
        deleteOfferUseCase: DeleteOfferUseCaseProtocol,
        getRestaurantProfileUseCase: GetRestaurantProfileUseCaseProtocol
    ) {
        self.getMyOffersUseCase = getMyOffersUseCase
        self.deleteOfferUseCase = deleteOfferUseCase
        self.getRestaurantProfileUseCase = getRestaurantProfileUseCase
    }

    /// The restaurant profile (name/image) can change server-side — e.g. after Edit Restaurant
    /// — so it's always refreshed on appear. The offers list is loaded through the skeleton only
    /// the first time; every later appearance (e.g. returning from Add/Edit Offer, which may
    /// reuse this same ViewModel instance via NavigationStack) re-fetches quietly in the
    /// background so new/edited offers show up without re-flickering the whole list.
    func onAppear(lang: String) async {
        currentLang = lang
        await refreshProfile()
        switch state {
        case .idle:
            await loadInitial()
        default:
            await reloadQuietly()
        }
    }

    /// `.task { }` on `DashboardScreen` only fires once per view identity — toggling the
    /// language flag mid-session needs this separate hook so the offers list re-fetches (and
    /// re-maps its bilingual title/description) in the new language instead of staying stuck.
    func onLanguageChange(lang: String) async {
        guard lang != currentLang else { return }
        currentLang = lang
        await reloadQuietly()
    }

    func refresh() async {
        await loadInitial()
        await refreshProfile()
    }

    /// Called when the last visible offer row appears — standard infinite-scroll trigger.
    func loadMore() {
        guard !isLoadingMore, hasNextPage else { return }
        Task { await loadNextPage() }
    }

    func requestDelete(id: Int64) {
        offerIdToDelete = id
    }

    func cancelDelete() {
        offerIdToDelete = nil
    }

    func confirmDelete() async {
        guard let id = offerIdToDelete else { return }
        offerIdToDelete = nil
        actionErrorMessage = nil
        do throws(AppError) {
            try await deleteOfferUseCase.execute(id: id)
            await loadInitial()
        } catch {
            // Deliberately does NOT touch `state` — the offers list (`.loaded`) was already
            // visible when the user chose to delete, and a failed delete shouldn't wipe it out
            // from under them. Surface the failure via `actionErrorMessage` instead.
            actionErrorMessage = error.displayMessage
        }
    }

    private func loadInitial() async {
        state = .loading
        currentPage = 1
        do throws(AppError) {
            let result = try await getMyOffersUseCase.execute(page: 1, limit: pageSize, lang: currentLang)
            hasNextPage = result.hasNextPage
            currentPage = result.nextPage ?? 1
            if result.items.isEmpty {
                state = .empty
            } else {
                state = .loaded(result.items.map { $0.toUi(for: language) })
            }
        } catch {
            state = .error(error.displayMessage)
        }
    }

    private func reloadQuietly() async {
        currentPage = 1
        do throws(AppError) {
            let result = try await getMyOffersUseCase.execute(page: 1, limit: pageSize, lang: currentLang)
            hasNextPage = result.hasNextPage
            currentPage = result.nextPage ?? 1
            state = result.items.isEmpty ? .empty : .loaded(result.items.map { $0.toUi(for: language) })
        } catch {
            // Silent background refresh — keep whatever was already on screen rather than
            // clobbering good data with an error banner.
        }
    }

    private func loadNextPage() async {
        guard case .loaded(let existing) = state else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do throws(AppError) {
            let result = try await getMyOffersUseCase.execute(page: currentPage, limit: pageSize, lang: currentLang)
            hasNextPage = result.hasNextPage
            currentPage = result.nextPage ?? currentPage
            state = .loaded(existing + result.items.map { $0.toUi(for: language) })
        } catch {
            // Keep the existing page visible; `hasNextPage` stays true so scrolling back to the
            // last row retries — no separate append-error surface exists on this screen yet.
        }
    }

    private var language: AppLanguage {
        AppLanguage(rawValue: currentLang) ?? .english
    }

    private func refreshProfile() async {
        if let restaurantProfile = try? await getRestaurantProfileUseCase.execute() {
            profile = restaurantProfile.toProfileUi()
        }
    }
}

// MARK: - Preview Factory

extension DashboardViewModel {
    @MainActor
    static func previewInstance(state: DashboardUiState = .idle) -> DashboardViewModel {
        let vm = DashboardViewModel(
            getMyOffersUseCase: FakeGetMyOffersUseCase(),
            deleteOfferUseCase: FakeDeleteOfferUseCase(),
            getRestaurantProfileUseCase: FakeGetRestaurantProfileUseCase()
        )
        vm.state = state
        vm.profile = RestaurantProfileUi(
            name: "The Golden Fork",
            description: "A perfect place for great food, warm vibes, and special offers.",
            imageURL: nil
        )
        return vm
    }
}

private struct FakeGetMyOffersUseCase: GetMyOffersUseCaseProtocol {
    func execute(page: Int, limit: Int, lang: String) async throws(AppError) -> PaginatedResult<Offer> {
        PaginatedResult(items: MockOfferRepository.seed, hasNextPage: false, nextPage: nil)
    }
}

private struct FakeDeleteOfferUseCase: DeleteOfferUseCaseProtocol {
    func execute(id: Int64) async throws(AppError) {}
}

private struct FakeGetRestaurantProfileUseCase: GetRestaurantProfileUseCaseProtocol {
    func execute() async throws(AppError) -> RestaurantEditData {
        RestaurantEditData(
            nameEn: "The Golden Fork",
            nameIs: "Gullni Gaffall",
            adminEmail: "info@goldenfork.is",
            phoneNumber: "555-1234",
            descriptionEn: "A perfect place for great food, warm vibes, and special offers.",
            descriptionIs: "Fullkominn staður fyrir frábæran mat.",
            address: "Laugavegur 1",
            city: "Reykjavik",
            country: "Iceland",
            latitude: 64.1466,
            longitude: -21.9426,
            website: "https://goldenfork.is",
            openingHours: []
        )
    }
}
