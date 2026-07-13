protocol GetOfferUseCaseProtocol: Sendable {
    func execute(id: Int64) async throws(AppError) -> Offer
}

final class GetOfferUseCase: GetOfferUseCaseProtocol, Sendable {
    private let offerRepository: OfferRepositoryProtocol

    init(offerRepository: OfferRepositoryProtocol) {
        self.offerRepository = offerRepository
    }

    func execute(id: Int64) async throws(AppError) -> Offer {
        guard id > 0 else {
            throw .validation(message: "Offer ID must be positive")
        }
        return try await offerRepository.getOffer(id: id)
    }
}
