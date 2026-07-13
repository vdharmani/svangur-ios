import SwiftUI

@MainActor
@Observable
final class DealDetailViewModel {
    private(set) var state: DealDetailUiState = .idle

    let dealId: Int64
    private let getOfferUseCase: GetOfferUseCaseProtocol

    init(dealId: Int64, getOfferUseCase: GetOfferUseCaseProtocol) {
        self.dealId = dealId
        self.getOfferUseCase = getOfferUseCase
    }

    func onAppear() async {
        guard state == .idle else { return }
        await load()
    }

    func refresh() async {
        await load()
    }

    private func load() async {
        state = .loading
        do throws(AppError) {
            let offer = try await getOfferUseCase.execute(id: dealId)
            state = .loaded(offer.toDealDetail())
        } catch {
            state = .error(error.displayMessage)
        }
    }
}

// MARK: - Preview Factory

extension DealDetailViewModel {
    @MainActor
    static func previewInstance(state: DealDetailUiState = .idle) -> DealDetailViewModel {
        let vm = DealDetailViewModel(
            dealId: 1,
            getOfferUseCase: FakeDealDetailGetOfferUseCase()
        )
        vm.state = state
        return vm
    }
}

private struct FakeDealDetailGetOfferUseCase: GetOfferUseCaseProtocol {
    func execute(id: Int64) async throws(AppError) -> Offer {
        MockOfferRepository.seed[0]
    }
}

// MARK: - Preview Fixture

extension DealDetailUi {
    static let preview = Offer(
        id: 1,
        restaurantId: 1,
        titleEn: "30% off all pizzas and pasta",
        titleIs: "30% afsláttur af pizzum og pasta",
        descriptionEn: "30% off all pizzas and pasta at Bella Italia, available Monday\u{2013}Wednesday from 11:00\u{2013}15:00.",
        descriptionIs: nil,
        categoryId: 1,
        discountValue: "30",
        customDiscountText: nil,
        validDays: [.monday, .tuesday, .wednesday, .thursday],
        validTimeStart: TimeOfDay(hour: 11, minute: 0),
        validTimeEnd: TimeOfDay(hour: 15, minute: 0),
        status: .approved,
        isActive: true,
        heroImageUrl: nil,
        imageUrls: [],
        imageIds: [],
        views: 0,
        clicks: 0
    ).toDealDetail()
}
