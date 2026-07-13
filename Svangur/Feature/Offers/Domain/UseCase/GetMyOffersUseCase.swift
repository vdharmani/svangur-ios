protocol GetMyOffersUseCaseProtocol: Sendable {
    func execute() async throws(AppError) -> [Offer]
}

final class GetMyOffersUseCase: GetMyOffersUseCaseProtocol, Sendable {
    private let offerRepository: OfferRepositoryProtocol

    init(offerRepository: OfferRepositoryProtocol) {
        self.offerRepository = offerRepository
    }

    func execute() async throws(AppError) -> [Offer] {
        try await offerRepository.getMyOffers()
    }
}
