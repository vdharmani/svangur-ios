protocol DeleteOfferUseCaseProtocol: Sendable {
    func execute(id: Int64) async throws(AppError)
}

final class DeleteOfferUseCase: DeleteOfferUseCaseProtocol, Sendable {
    private let offerRepository: OfferRepositoryProtocol

    init(offerRepository: OfferRepositoryProtocol) {
        self.offerRepository = offerRepository
    }

    func execute(id: Int64) async throws(AppError) {
        guard id > 0 else {
            throw .validation(message: "Offer ID must be positive")
        }
        try await offerRepository.deleteOffer(id: id)
    }
}
