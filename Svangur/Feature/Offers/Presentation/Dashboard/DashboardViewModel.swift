import SwiftUI

@MainActor
@Observable
final class DashboardViewModel {
    private(set) var state: DashboardUiState = .idle
    var offerIdToDelete: Int64?

    private let getMyOffersUseCase: GetMyOffersUseCaseProtocol
    private let deleteOfferUseCase: DeleteOfferUseCaseProtocol

    init(
        getMyOffersUseCase: GetMyOffersUseCaseProtocol,
        deleteOfferUseCase: DeleteOfferUseCaseProtocol
    ) {
        self.getMyOffersUseCase = getMyOffersUseCase
        self.deleteOfferUseCase = deleteOfferUseCase
    }

    func onAppear() async {
        if case .loaded = state { return }
        await load()
    }

    func refresh() async {
        await load()
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
            await load()
        } catch {
            state = .error(error.displayMessage)
        }
    }

    private func load() async {
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
}

// MARK: - Preview Factory

extension DashboardViewModel {
    @MainActor
    static func previewInstance(state: DashboardUiState = .idle) -> DashboardViewModel {
        let vm = DashboardViewModel(
            getMyOffersUseCase: FakeGetMyOffersUseCase(),
            deleteOfferUseCase: FakeDeleteOfferUseCase()
        )
        vm.state = state
        return vm
    }
}

private struct FakeGetMyOffersUseCase: GetMyOffersUseCaseProtocol {
    func execute() async throws(AppError) -> [Offer] { MockOfferRepository.seed }
}

private struct FakeDeleteOfferUseCase: DeleteOfferUseCaseProtocol {
    func execute(id: Int64) async throws(AppError) {}
}
