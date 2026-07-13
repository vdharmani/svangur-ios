import SwiftUI

@MainActor
@Observable
final class OfferDetailViewModel {
    private(set) var state: OfferDetailUiState = .idle
    private(set) var isDeleting = false

    let offerId: Int64

    private let getOfferUseCase: GetOfferUseCaseProtocol
    private let deleteOfferUseCase: DeleteOfferUseCaseProtocol

    init(
        offerId: Int64,
        getOfferUseCase: GetOfferUseCaseProtocol,
        deleteOfferUseCase: DeleteOfferUseCaseProtocol
    ) {
        self.offerId = offerId
        self.getOfferUseCase = getOfferUseCase
        self.deleteOfferUseCase = deleteOfferUseCase
    }

    func onAppear() async {
        await load()
    }

    func refresh() async {
        await load()
    }

    func deleteOffer() async {
        isDeleting = true
        defer { isDeleting = false }
        do throws(AppError) {
            try await deleteOfferUseCase.execute(id: offerId)
            state = .deleted
        } catch {
            state = .error(error.displayMessage)
        }
    }

    private func load() async {
        state = .loading
        do throws(AppError) {
            let offer = try await getOfferUseCase.execute(id: offerId)
            state = .loaded(offer.toUi())
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
            deleteOfferUseCase: FakeDeleteOfferUseCase()
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
