import SwiftUI
import Combine

@MainActor
final class DealDetailViewModel: ObservableObject {
    @Published private(set) var state: DealDetailUiState = .idle

    let dealId: Int64
    private let getDealDetailUseCase: GetDealDetailUseCaseProtocol

    init(dealId: Int64, getDealDetailUseCase: GetDealDetailUseCaseProtocol) {
        self.dealId = dealId
        self.getDealDetailUseCase = getDealDetailUseCase
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
            let deal = try await getDealDetailUseCase.execute(id: dealId)
            state = .loaded(deal.toDealDetail())
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
            getDealDetailUseCase: FakeGetDealDetailUseCase()
        )
        vm.state = state
        return vm
    }
}

private struct FakeGetDealDetailUseCase: GetDealDetailUseCaseProtocol {
    func execute(id: Int64) async throws(AppError) -> DealListing {
        DealDetailUi.previewDealListing
    }
}

// MARK: - Preview Fixture

extension DealDetailUi {
    static let previewDealListing = DealListing(
        id: "1",
        restaurantId: "1",
        restaurantName: "Bella Italia",
        categoryId: "1",
        categoryName: "Italian",
        title: "30% off all pizzas and pasta",
        description: "30% off all pizzas and pasta at Bella Italia, available Monday\u{2013}Wednesday from 11:00\u{2013}15:00.",
        discountType: nil,
        discountPercent: 30,
        customDiscountText: "30% off",
        validTimeStart: "11:00",
        validTimeEnd: "15:00",
        validDays: [0, 1, 2],
        heroImageUrl: nil,
        latitude: nil,
        longitude: nil,
        distanceKm: nil,
        isOpenNow: nil,
        rating: nil
    )

    static let preview = previewDealListing.toDealDetail()
}
