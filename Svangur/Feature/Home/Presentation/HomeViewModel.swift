import SwiftUI

@MainActor
@Observable
final class HomeViewModel {
    // MARK: - Filter state
    var searchQuery: String = ""
    private(set) var selectedCategory: OfferCategory?
    private(set) var selectedDiscountFilter: DiscountFilter = .all
    private(set) var selectedDay: Weekday?
    private(set) var openNowOnly: Bool = true

    // MARK: - UI state
    private(set) var state: HomeUiState = .idle
    var viewMode: ViewMode = .list

    // MARK: - Map state
    let mapPins: [DealMapPin] = DealMapPin.mockPins
    private(set) var selectedPin: DealMapPin?

    enum ViewMode { case list, map }

    // MARK: - Dependencies
    private let getNearbyOffersUseCase: GetNearbyOffersUseCaseProtocol
    private var allOffers: [Offer] = []

    init(getNearbyOffersUseCase: GetNearbyOffersUseCaseProtocol) {
        self.getNearbyOffersUseCase = getNearbyOffersUseCase
        self.selectedDay = currentWeekday()
    }

    // MARK: - Lifecycle

    func onAppear() async {
        guard state == .idle else { return }
        await loadOffers()
    }

    func refresh() async {
        await loadOffers()
    }

    // MARK: - Filter actions

    func selectCategory(_ category: OfferCategory?) {
        selectedCategory = category
        applyFilters()
    }

    func selectDiscountFilter(_ filter: DiscountFilter) {
        selectedDiscountFilter = filter
        applyFilters()
    }

    func selectDay(_ day: Weekday?) {
        selectedDay = day
        applyFilters()
    }

    func toggleOpenNow() {
        openNowOnly.toggle()
        applyFilters()
    }

    func toggleViewMode() {
        viewMode = viewMode == .list ? .map : .list
    }

    func selectPin(_ pin: DealMapPin?) {
        selectedPin = pin
    }

    // MARK: - Computed

    var orderedDays: [Weekday] {
        let today = currentWeekday()
        let all = Weekday.allCases
        guard let idx = all.firstIndex(of: today) else { return all }
        return Array(all[idx...]) + Array(all[..<idx])
    }

    var todayWeekday: Weekday { currentWeekday() }

    // MARK: - Private

    private func loadOffers() async {
        state = .loading
        do throws(AppError) {
            allOffers = try await getNearbyOffersUseCase.execute()
            applyFilters()
        } catch {
            state = .error(error.displayMessage)
        }
    }

    private func applyFilters() {
        var filtered = allOffers.filter { $0.isActive }

        // JUDGMENT CALL (reshape to real backend API): `selectedCategory` is the old fixed
        // `OfferCategory` enum, kept only for Home's hardcoded filter-chip UI (see
        // `OfferCategory.swift`). It no longer has a data-level mapping onto the backend's
        // dynamic `categoryId` — wiring that up would mean threading the real category list
        // through Home, which is out of scope for this "minimal rewire" pass. Category
        // selection therefore only drives chip highlighting now, not actual filtering.

        if selectedDiscountFilter != .all {
            filtered = filtered.filter { selectedDiscountFilter.matches($0.discountValue) }
        }

        if let day = selectedDay {
            filtered = filtered.filter { $0.validDays.contains(day) }
        }

        if openNowOnly {
            filtered = filtered.filter { offer in
                Offer.isCurrentlyOpen(
                    validDays: offer.validDays,
                    from: offer.validTimeStart,
                    until: offer.validTimeEnd
                )
            }
        }

        if !searchQuery.isEmpty {
            let query = searchQuery.lowercased()
            filtered = filtered.filter {
                $0.titleEn.lowercased().contains(query) ||
                ($0.descriptionEn ?? "").lowercased().contains(query)
            }
        }

        let mockNames = ["Pizza Palace", "Burger Joint", "Sweet Bites", "Noodle House", "Taco Town"]
        let deals = filtered.enumerated().map { idx, offer in
            offer.toDealCard(
                restaurantName: mockNames[idx % mockNames.count],
                distance: String(format: "%.1f km", Double.random(in: 0.3...5.0))
            )
        }

        state = deals.isEmpty ? .empty : .loaded(deals)
    }

    private func currentWeekday() -> Weekday {
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
}

// MARK: - Preview Factory

extension HomeViewModel {
    @MainActor
    static func previewInstance(state: HomeUiState = .idle) -> HomeViewModel {
        let vm = HomeViewModel(
            getNearbyOffersUseCase: FakeGetNearbyOffersUseCase()
        )
        vm.state = state
        return vm
    }
}

private struct FakeGetNearbyOffersUseCase: GetNearbyOffersUseCaseProtocol {
    func execute() async throws(AppError) -> [Offer] { [] }
}
