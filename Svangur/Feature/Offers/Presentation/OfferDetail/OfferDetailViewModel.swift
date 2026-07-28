import SwiftUI
import Combine

@MainActor
final class OfferDetailViewModel: ObservableObject {
    @Published private(set) var state: OfferDetailUiState = .idle
    @Published private(set) var isDeleting = false

    /// Transient error from a *failed action* (currently: delete) taken while the offer detail
    /// was already loaded and visible. Kept separate from `state` so a delete failure surfaces
    /// as a small banner (via `SvErrorBanner`) instead of clobbering the loaded detail content
    /// with the full-screen `.error` state — the previous behavior replaced the visible offer
    /// with an error screen just because the delete call failed. Cleared at the start of the
    /// next delete attempt.
    @Published private(set) var actionErrorMessage: String?

    let offerId: Int64

    private let getOfferUseCase: GetOfferUseCaseProtocol
    private let deleteOfferUseCase: DeleteOfferUseCaseProtocol
    private let getOfferAnalyticsUseCase: GetOfferAnalyticsUseCaseProtocol
    private let getRestaurantProfileUseCase: GetRestaurantProfileUseCaseProtocol
    private let dealRepository: DealRepositoryProtocol
    private var currentLang: String = AppLanguage.english.rawValue

    init(
        offerId: Int64,
        getOfferUseCase: GetOfferUseCaseProtocol,
        deleteOfferUseCase: DeleteOfferUseCaseProtocol,
        getOfferAnalyticsUseCase: GetOfferAnalyticsUseCaseProtocol,
        getRestaurantProfileUseCase: GetRestaurantProfileUseCaseProtocol,
        dealRepository: DealRepositoryProtocol
    ) {
        self.offerId = offerId
        self.getOfferUseCase = getOfferUseCase
        self.deleteOfferUseCase = deleteOfferUseCase
        self.getOfferAnalyticsUseCase = getOfferAnalyticsUseCase
        self.getRestaurantProfileUseCase = getRestaurantProfileUseCase
        self.dealRepository = dealRepository
    }

    func onAppear(lang: String) async {
        currentLang = lang
        await load()
    }

    func refresh() async {
        await load()
    }

    /// `.task { }` on `OfferDetailScreen` only fires once per view identity — toggling the
    /// language flag mid-session needs this separate hook so the offer's bilingual
    /// title/description re-map to the new language instead of staying stuck.
    func onLanguageChange(lang: String) async {
        guard lang != currentLang else { return }
        currentLang = lang
        await load()
    }

    func deleteOffer() async {
        isDeleting = true
        actionErrorMessage = nil
        defer { isDeleting = false }
        do throws(AppError) {
            try await deleteOfferUseCase.execute(id: offerId)
            state = .deleted
        } catch {
            // Deliberately does NOT touch `state` — the offer (`.loaded`) was already visible
            // when the user chose to delete, and a failed delete shouldn't replace it with a
            // full-screen error. Surface the failure via `actionErrorMessage` instead.
            actionErrorMessage = error.displayMessage
        }
    }

    /// Analytics/category/restaurant-profile are enrichment data, not required for the screen to
    /// render — each is fetched best-effort (`try?`) alongside the required offer fetch so a
    /// hiccup in any one of them degrades to its placeholder/hidden state instead of blocking the
    /// whole detail screen behind a full-screen error.
    private func load() async {
        state = .loading
        let lang = currentLang
        do throws(AppError) {
            // NOTE: the offer fetch is a plain `try await` (not `async let`) because typed throws
            // don't propagate through `async let` bindings — but it still runs concurrently with
            // the enrichment fetches below, since their child tasks start immediately at the
            // `async let` declaration regardless of when this function suspends to await them.
            async let analyticsTask: OfferAnalytics? = try? await getOfferAnalyticsUseCase.execute(id: offerId)
            async let categoriesTask: [DealCategory] = (try? await dealRepository.listOwnerCategories(lang: lang)) ?? []
            async let profileTask: RestaurantEditData? = try? await getRestaurantProfileUseCase.execute()

            let offer = try await getOfferUseCase.execute(id: offerId)
            state = .loaded(offer.toUi(
                for: AppLanguage(rawValue: lang) ?? .english,
                categories: await categoriesTask,
                restaurantProfile: await profileTask,
                analytics: await analyticsTask
            ))
        } catch {
            state = .error(error.displayMessage)
        }
    }
}

// MARK: - Preview Factory

extension OfferDetailViewModel {
    @MainActor
    static func previewInstance(state: OfferDetailUiState = .idle) -> OfferDetailViewModel {
        let vm = OfferDetailViewModel(
            offerId: 1,
            getOfferUseCase: FakeGetOfferUseCase(),
            deleteOfferUseCase: FakeDeleteOfferUseCase(),
            getOfferAnalyticsUseCase: FakeGetOfferAnalyticsUseCase(),
            getRestaurantProfileUseCase: FakeGetRestaurantProfileUseCase(),
            dealRepository: FakeDealRepository()
        )
        vm.state = state
        return vm
    }
}

private struct FakeGetOfferUseCase: GetOfferUseCaseProtocol {
    func execute(id: Int64) async throws(AppError) -> Offer { MockOfferRepository.seed[0] }
}
private struct FakeDeleteOfferUseCase: DeleteOfferUseCaseProtocol {
    func execute(id: Int64) async throws(AppError) {}
}
private struct FakeGetOfferAnalyticsUseCase: GetOfferAnalyticsUseCaseProtocol {
    func execute(id: Int64) async throws(AppError) -> OfferAnalytics {
        OfferAnalytics(
            views: 1245, viewsChangePct: 12,
            clicks: 158, clicksChangePct: -6,
            mapActions: 42, mapActionsChangePct: 3,
            callActions: 18, callActionsChangePct: 5,
            websiteActions: 27, websiteActionsChangePct: -2,
            period: "last_7_days"
        )
    }
}
private struct FakeGetRestaurantProfileUseCase: GetRestaurantProfileUseCaseProtocol {
    func execute() async throws(AppError) -> RestaurantEditData {
        RestaurantEditData(
            nameEn: "Bella Italia", nameIs: "Bella Italia",
            adminEmail: "info@bellaitalia.is", phoneNumber: "+354 555 1234",
            descriptionEn: "", descriptionIs: "",
            address: "Laugavegur 1", city: "Reykjavik", country: "Iceland",
            latitude: 64.1466, longitude: -21.9426,
            website: "https://bellaitalia.is",
            openingHours: []
        )
    }
}
private struct FakeDealRepository: DealRepositoryProtocol {
    func listDeals(
        latitude: Double?, longitude: Double?, categoryId: String?, discountFilter: String?,
        day: String?, openNow: Bool?, lang: String?, page: Int?, limit: Int?, deviceId: String?
    ) async throws(AppError) -> [DealListing] { [] }
    func listCategories(lang: String) async throws(AppError) -> [DealCategory] { [] }
    func listOwnerCategories(lang: String) async throws(AppError) -> [DealCategory] {
        [DealCategory(id: "1", slug: "chinese", nameEn: "Chinese", nameIs: "Kínverskt", sortOrder: 0)]
    }
    func listDiscountFilters(lang: String) async throws(AppError) -> [DiscountUserFilter] { [] }
    func listOwnerDiscountOptions(lang: String) async throws(AppError) -> [DiscountOwnerOption] { [] }
    func getDeal(id: String, lang: String?) async throws(AppError) -> DealListing { throw .notFound() }
    func trackView(id: String) async throws(AppError) {}
    func trackClick(id: String) async throws(AppError) {}
}
