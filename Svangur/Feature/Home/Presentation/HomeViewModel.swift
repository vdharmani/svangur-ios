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
    /// Fetched independently of `state` via `loadMapPins()` (`GET /offers?lang=...`, no
    /// lat/lng/device_id — the map shows every deal with a coordinate, not a location-sorted,
    /// filtered feed). Deals without a coordinate are dropped (`DealListing.toMapPin()`).
    @Published private(set) var mapPins: [DealMapPin] = []
    @Published private(set) var selectedPin: DealMapPin?

    enum ViewMode { case list, map }

    // MARK: - Dependencies
    private let getHomeDealsUseCase: GetHomeDealsUseCaseProtocol
    private let getMapPinsUseCase: GetMapPinsUseCaseProtocol
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
        getMapPinsUseCase: GetMapPinsUseCaseProtocol,
        getCurrentLocationUseCase: GetCurrentLocationUseCaseProtocol,
        dealRepository: DealRepositoryProtocol,
        getDaysUseCase: GetDaysUseCaseProtocol,
        selectedLocationStore: SelectedLocationStoreProtocol,
        deviceId: String
    ) {
        self.getHomeDealsUseCase = getHomeDealsUseCase
        self.getMapPinsUseCase = getMapPinsUseCase
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
        async let mapPinsTask: Void = loadMapPins(lang: lang)
        // Only resolve GPS location on the true first appearance. `HomeScreen` disappears and
        // reappears (re-firing `.task { }` → this method) every time a screen is pushed/popped
        // on top of it — including the Select/Confirm Location flow. Re-running unconditionally
        // would silently overwrite a location the user just manually confirmed (delivered live by
        // `observeSelectedLocation()`, which keeps running in the background across that
        // disappearance) with the stale cached GPS snapshot the moment Home comes back.
        if currentLocation == nil {
            await loadLocation()
        }
        if state == .idle {
            await loadOffers()
        }
        await discountFiltersTask
        await daysTask
        await categoriesTask
        await mapPinsTask
        observeSelectedLocation()
    }

    func refresh() async {
        async let offersTask: Void = loadOffers()
        async let mapPinsTask: Void = loadMapPins(lang: currentLang)
        await offersTask
        await mapPinsTask
    }

    /// `.task { }` on `HomeScreen` only fires once per view identity, so toggling the language
    /// flag mid-session never re-triggers `onAppear` — every server-driven piece of UI (days,
    /// categories, discount filters, deals, map pins) has to be explicitly re-fetched here
    /// instead, or it stays stuck showing whatever language was active on first load.
    func onLanguageChange(lang: String) async {
        guard lang != currentLang else { return }
        currentLang = lang
        async let discountFiltersTask: Void = loadDiscountFilters(lang: lang)
        async let daysTask: Void = loadDays(lang: lang, autoSelectToday: false)
        async let categoriesTask: Void = loadCategories(lang: lang)
        async let mapPinsTask: Void = loadMapPins(lang: lang)
        await loadOffers()
        await discountFiltersTask
        await daysTask
        await categoriesTask
        await mapPinsTask
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

    /// `autoSelectToday` is only meant for the very first load (`onAppear`), where
    /// `selectedDayKey` may still hold the locally-computed fallback guess made before this
    /// server response arrived — correcting it there can trigger an extra `loadOffers()`.
    /// `onLanguageChange` passes `false`: `selectedDayKey` is already correct by then (only the
    /// display labels change with language, not which day is "today"), and `onLanguageChange`
    /// already reloads offers itself once — letting this cascade too would fetch them twice
    /// per toggle.
    private func loadDays(lang: String, autoSelectToday: Bool = true) async {
        do throws(AppError) {
            let fetched = try await getDaysUseCase.execute(lang: lang, tz: TimeZone.current.identifier)
            guard !fetched.isEmpty else { return }
            days = fetched
            if autoSelectToday, !userSelectedDay {
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
                // The API's `open_now` semantics are inverted relative to the toggle,
                // and `open_now=false` must be omitted entirely rather than sent:
                // toggle ON → no param, toggle OFF → open_now=true.
                openNow: openNowOnly ? nil : true,
                lang: currentLang,
                page: 1,
                limit: 20,
                deviceId: deviceId
            )
            refreshErrorMessage = nil
            state = deals.isEmpty ? .empty : .loaded(deals.map { $0.toDealCard() })
        } catch {
            if isRefreshOfExistingContent {
                refreshErrorMessage = error.displayMessage
            } else {
                state = .error(error.displayMessage)
            }
        }
    }

    /// Fetches the unfiltered feed (`GET /offers?lang=...`, no lat/lng/device_id) that backs the
    /// map pins — independent of `loadOffers()`'s filters/location so a pin placement failure or
    /// refresh never blocks the list, and vice versa.
    private func loadMapPins(lang: String) async {
        do throws(AppError) {
            let deals = try await getMapPinsUseCase.execute(lang: lang)
            mapPins = deals.compactMap { $0.toMapPin() }
        } catch {
            // Keep whatever pins are already on screen rather than clearing the map on failure.
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
            getMapPinsUseCase: FakeGetMapPinsUseCase(),
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
        openNow: Bool?,
        lang: String,
        page: Int,
        limit: Int,
        deviceId: String
    ) async throws(AppError) -> [DealListing] { [] }
}

private struct FakeGetMapPinsUseCase: GetMapPinsUseCaseProtocol {
    func execute(lang: String) async throws(AppError) -> [DealListing] { [] }
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
    func getDeal(id: String, lang: String?) async throws(AppError) -> DealListing {
        throw .notFound()
    }
    func trackView(id: String) async throws(AppError) {}
    func trackClick(id: String) async throws(AppError) {}
}

private struct FakeGetDaysUseCase: GetDaysUseCaseProtocol {
    func execute(lang: String, tz: String) async throws(AppError) -> [DayItem] { [] }
}
