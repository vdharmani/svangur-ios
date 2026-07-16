import SwiftUI
import Combine

@MainActor
final class HomeViewModel: ObservableObject {
    // MARK: - Filter state
    /// Real, dynamic categories (`GET /categories` `user_filters` via `DealRepositoryProtocol`).
    @Published private(set) var categories: [DealCategory] = []
    @Published private(set) var selectedCategoryId: String?
    /// Real, dynamic discount filters (`GET /discount-options` `user_filters` via
    /// `DealRepositoryProtocol`). Falls back to `Self.fallbackDiscountFilters` if the fetch
    /// fails or returns empty, so the chip row always has something selectable.
    @Published private(set) var discountFilters: [DiscountUserFilter] = HomeViewModel.fallbackDiscountFilters
    @Published private(set) var selectedDiscountFilterKey: String = "all"
    /// Real, dynamic days (`GET /days` via `GetDaysUseCaseProtocol`) — labels, key order, and
    /// which one `isToday` all come from the server (tz-aware), not the device's local
    /// `Calendar`. Falls back to a locally-computed Mon–Sun list if the fetch fails.
    @Published private(set) var days: [DayItem] = HomeViewModel.fallbackDays()
    @Published private(set) var selectedDayKey: String?
    /// Guards against an in-flight `loadDays(lang:)` overwriting a day the user already picked.
    private var userSelectedDay = false
    @Published private(set) var openNowOnly: Bool = true

    // MARK: - UI state
    @Published private(set) var state: HomeUiState = .idle
    @Published var viewMode: ViewMode = .list
    @Published private(set) var locationDisplayText: String = "Detecting location…"
    /// A pull-to-refresh (or filter-change) failure while deals are already visible — surfaced
    /// as a banner rather than replacing `state` (which would wipe the still-valid list).
    @Published private(set) var refreshErrorMessage: String?

    // MARK: - Map state
    /// Derived from the same `GET /offers` response as `state` — populated in `loadOffers()`.
    /// Deals without a coordinate are dropped (`DealListing.toMapPin()`), so this can be a
    /// shorter list than the deals shown in `state`.
    @Published private(set) var mapPins: [DealMapPin] = []
    @Published private(set) var selectedPin: DealMapPin?

    enum ViewMode { case list, map }

    // MARK: - Dependencies
    private let getHomeDealsUseCase: GetHomeDealsUseCaseProtocol
    private let getCurrentLocationUseCase: GetCurrentLocationUseCaseProtocol
    private let dealRepository: DealRepositoryProtocol
    private let getDaysUseCase: GetDaysUseCaseProtocol
    private let selectedLocationStore: SelectedLocationStoreProtocol

    // MARK: - Configuration
    private let deviceId: String

    // MARK: - Session state (resolved once per `onAppear`, reused by filter changes/refresh)
    private var currentLang: String = AppLanguage.english.rawValue
    /// The device's resolved coordinate + display text — `Published` so `HomeScreen` can center
    /// the map on the real location instead of a hardcoded region.
    @Published private(set) var currentLocation: LocationSnapshot?
    /// Listens for a location manually confirmed on `ConfirmLocationScreen` — started once from
    /// `onAppear`, cancelled in `deinit` per this project's memory-management rules.
    private var locationObservationTask: Task<Void, Never>?

    init(
        getHomeDealsUseCase: GetHomeDealsUseCaseProtocol,
        getCurrentLocationUseCase: GetCurrentLocationUseCaseProtocol,
        dealRepository: DealRepositoryProtocol,
        getDaysUseCase: GetDaysUseCaseProtocol,
        selectedLocationStore: SelectedLocationStoreProtocol,
        deviceId: String
    ) {
        self.getHomeDealsUseCase = getHomeDealsUseCase
        self.getCurrentLocationUseCase = getCurrentLocationUseCase
        self.dealRepository = dealRepository
        self.getDaysUseCase = getDaysUseCase
        self.selectedLocationStore = selectedLocationStore
        self.deviceId = deviceId
        self.selectedDayKey = days.first(where: \.isToday)?.key
    }

    deinit {
        locationObservationTask?.cancel()
    }

    // MARK: - Lifecycle

    func onAppear(lang: String) async {
        currentLang = lang
        async let discountFiltersTask: Void = loadDiscountFilters(lang: lang)
        async let daysTask: Void = loadDays(lang: lang)
        async let categoriesTask: Void = loadCategories(lang: lang)
        await loadLocation()
        if state == .idle {
            await loadOffers()
        }
        await discountFiltersTask
        await daysTask
        await categoriesTask
        observeSelectedLocation()
    }

    func refresh() async {
        await loadOffers()
    }

    // MARK: - Filter actions

    func selectCategory(_ category: DealCategory?) {
        selectedCategoryId = category?.id
        Task { await loadOffers() }
    }

    func selectDiscountFilter(_ filter: DiscountUserFilter) {
        selectedDiscountFilterKey = filter.key
        Task { await loadOffers() }
    }

    func selectDay(_ day: DayItem?) {
        userSelectedDay = true
        selectedDayKey = day?.key
        Task { await loadOffers() }
    }

    func toggleOpenNow() {
        openNowOnly.toggle()
        Task { await loadOffers() }
    }

    func toggleViewMode() {
        viewMode = viewMode == .list ? .map : .list
    }

    func selectPin(_ pin: DealMapPin?) {
        selectedPin = pin
    }

    // MARK: - Private

    private func loadLocation() async {
        do throws(AppError) {
            let snapshot = try await getCurrentLocationUseCase.execute()
            currentLocation = snapshot
            locationDisplayText = snapshot.displayText
        } catch {
            currentLocation = nil
            locationDisplayText = "Location unavailable"
        }
    }

    private func loadDiscountFilters(lang: String) async {
        do throws(AppError) {
            let fetched = try await dealRepository.listDiscountFilters(lang: lang)
            discountFilters = fetched.isEmpty ? Self.fallbackDiscountFilters : fetched
        } catch {
            discountFilters = Self.fallbackDiscountFilters
        }
    }

    /// Subscribes once to `SelectedLocationStore` — when `ConfirmLocationScreen` publishes a
    /// manually-picked coordinate, adopts it as `currentCoordinate` and refetches the feed.
    private func observeSelectedLocation() {
        guard locationObservationTask == nil else { return }
        locationObservationTask = Task { [weak self] in
            guard let self else { return }
            for await location in await self.selectedLocationStore.updates() {
                guard !Task.isCancelled else { return }
                self.currentLocation = LocationSnapshot(
                    latitude: location.latitude,
                    longitude: location.longitude,
                    displayText: location.displayText
                )
                self.locationDisplayText = location.displayText
                await self.loadOffers()
            }
        }
    }

    private func loadCategories(lang: String) async {
        do throws(AppError) {
            categories = try await dealRepository.listCategories(lang: lang)
        } catch {
            categories = []
        }
    }

    private func loadDays(lang: String) async {
        do throws(AppError) {
            let fetched = try await getDaysUseCase.execute(lang: lang, tz: TimeZone.current.identifier)
            guard !fetched.isEmpty else { return }
            days = fetched
            if !userSelectedDay {
                let resolvedTodayKey = fetched.first(where: \.isToday)?.key
                // The initial `loadOffers()` in `onAppear` may already have fired using the
                // locally-computed fallback day key, before this server response arrived. If the
                // server's tz-aware "today" key differs, refetch so the deals list matches what
                // the (now updated) Today chip shows.
                if resolvedTodayKey != selectedDayKey {
                    selectedDayKey = resolvedTodayKey
                    await loadOffers()
                }
            }
        } catch {
            // Keep the locally-computed fallback days.
        }
    }

    /// Fetches the consumer feed (`GET /offers`) with the current filter selection — the
    /// server applies discount/day/open-now filtering and distance sorting, so no client-side
    /// filtering is needed once this returns.
    private func loadOffers() async {
        let isRefreshOfExistingContent: Bool
        switch state {
        case .loaded, .empty: isRefreshOfExistingContent = true
        default: isRefreshOfExistingContent = false
        }

        if !isRefreshOfExistingContent {
            state = .loading
        }
        do throws(AppError) {
            let deals = try await getHomeDealsUseCase.execute(
                latitude: currentLocation?.latitude,
                longitude: currentLocation?.longitude,
                categoryId: selectedCategoryId,
                discountFilter: selectedDiscountFilterKey,
                day: selectedDayKey,
                // The API's `open_now` semantics are inverted relative to the toggle:
                // toggle ON → open_now=false, toggle OFF → open_now=true.
                openNow: !openNowOnly,
                lang: currentLang,
                page: 1,
                limit: 20,
                deviceId: deviceId
            )
            refreshErrorMessage = nil
            state = deals.isEmpty ? .empty : .loaded(deals.map { $0.toDealCard() })
            mapPins = deals.compactMap { $0.toMapPin() }
        } catch {
            if isRefreshOfExistingContent {
                refreshErrorMessage = error.displayMessage
            } else {
                state = .error(error.displayMessage)
            }
        }
    }

    private static func currentWeekday() -> Weekday {
        let weekdayComponent = Calendar.current.component(.weekday, from: Date())
        return switch weekdayComponent {
        case 1: .sunday
        case 2: .monday
        case 3: .tuesday
        case 4: .wednesday
        case 5: .thursday
        case 6: .friday
        case 7: .saturday
        default: .monday
        }
    }

    /// JUDGMENT CALL: locally-computed (device `Calendar`, not server tz) fallback used only
    /// before the real `/days` fetch resolves, or if it fails.
    private static func fallbackDays() -> [DayItem] {
        let today = currentWeekday()
        return Weekday.allCases.map { day in
            DayItem(key: day.dayCode, label: day.shortName, shortLabel: day.shortName, isToday: day == today)
        }
    }

    /// JUDGMENT CALL: small hardcoded fallback mirroring the real `/discount-options`
    /// `user_filters` shape, so the discount chip row stays functional if
    /// `listDiscountFilters(lang:)` fails or the backend returns nothing — NOT meant to be a
    /// faithful mirror of any real filter ids.
    private static let fallbackDiscountFilters: [DiscountUserFilter] = [
        DiscountUserFilter(id: 1, key: "all", label: "All Offers"),
        DiscountUserFilter(id: 2, key: "20_plus", label: "20%+"),
        DiscountUserFilter(id: 3, key: "30_plus", label: "30%+"),
        DiscountUserFilter(id: 4, key: "2_for_1", label: "2 for 1")
    ]
}

// MARK: - Preview Factory

extension HomeViewModel {
    @MainActor
    static func previewInstance(state: HomeUiState = .idle) -> HomeViewModel {
        let vm = HomeViewModel(
            getHomeDealsUseCase: FakeGetHomeDealsUseCase(),
            getCurrentLocationUseCase: FakeGetCurrentLocationUseCase(),
            dealRepository: FakeDealRepository(),
            getDaysUseCase: FakeGetDaysUseCase(),
            selectedLocationStore: FakeSelectedLocationStore(),
            deviceId: "preview-device"
        )
        vm.state = state
        return vm
    }
}

private struct FakeGetHomeDealsUseCase: GetHomeDealsUseCaseProtocol {
    func execute(
        latitude: Double?,
        longitude: Double?,
        categoryId: String?,
        discountFilter: String,
        day: String?,
        openNow: Bool,
        lang: String,
        page: Int,
        limit: Int,
        deviceId: String
    ) async throws(AppError) -> [DealListing] { [] }
}

private struct FakeGetCurrentLocationUseCase: GetCurrentLocationUseCaseProtocol {
    func execute() async throws(AppError) -> LocationSnapshot {
        LocationSnapshot(latitude: 64.1466, longitude: -21.9426, displayText: "Reykjavik, Iceland")
    }
}

private actor FakeSelectedLocationStore: SelectedLocationStoreProtocol {
    func set(_ location: SelectedLocation) {}
    func updates() -> AsyncStream<SelectedLocation> { AsyncStream { _ in } }
}

private struct FakeDealRepository: DealRepositoryProtocol {
    func listDeals(
        latitude: Double?,
        longitude: Double?,
        categoryId: String?,
        discountFilter: String?,
        day: String?,
        openNow: Bool?,
        lang: String?,
        page: Int?,
        limit: Int?,
        deviceId: String?
    ) async throws(AppError) -> [DealListing] { [] }
    func listCategories(lang: String) async throws(AppError) -> [DealCategory] { [] }
    func listOwnerCategories(lang: String) async throws(AppError) -> [DealCategory] { [] }
    func listDiscountFilters(lang: String) async throws(AppError) -> [DiscountUserFilter] { [] }
    func listOwnerDiscountOptions(lang: String) async throws(AppError) -> [DiscountOwnerOption] { [] }
    func getDeal(id: String) async throws(AppError) -> DealListing {
        throw .notFound()
    }
    func trackView(id: String) async throws(AppError) {}
    func trackClick(id: String) async throws(AppError) {}
}

private struct FakeGetDaysUseCase: GetDaysUseCaseProtocol {
    func execute(lang: String, tz: String) async throws(AppError) -> [DayItem] { [] }
}
