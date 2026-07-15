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
