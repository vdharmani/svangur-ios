import SwiftUI

@MainActor
@Observable
final class DashboardViewModel {
    private(set) var state: DashboardUiState = .idle
    private(set) var profile: RestaurantProfileUi?
    var offerIdToDelete: Int64?

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
    /// — so it's always refreshed on appear. The offers list, by contrast, only reloads once
    /// per appearance of this screen (guarded below) so returning from an unrelated screen
    /// (offer detail, etc.) doesn't re-flicker the whole list through its loading skeleton.
    func onAppear() async {
        await refreshProfile()
        guard case .idle = state else { return }
        await loadOffers()
    }

    func refresh() async {
        await loadOffers()
        await refreshProfile()
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
        do throws(AppError) {
            try await deleteOfferUseCase.execute(id: id)
            await loadOffers()
        } catch {
            state = .error(error.displayMessage)
        }
    }

    private func loadOffers() async {
        state = .loading
        do throws(AppError) {
            let offers = try await getMyOffersUseCase.execute()
            if offers.isEmpty {
                state = .empty
            } else {
                state = .loaded(offers.map { $0.toUi() })
            }
        } catch {
            state = .error(error.displayMessage)
        }
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
    func execute() async throws(AppError) -> [Offer] { MockOfferRepository.seed }
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
