protocol GetMyOffersUseCaseProtocol: Sendable {
    func execute(page: Int, limit: Int) async throws(AppError) -> PaginatedResult<Offer>
}

final class GetMyOffersUseCase: GetMyOffersUseCaseProtocol, Sendable {
    private let offerRepository: OfferRepositoryProtocol

    init(offerRepository: OfferRepositoryProtocol) {
        self.offerRepository = offerRepository
    }

    func execute(page: Int, limit: Int) async throws(AppError) -> PaginatedResult<Offer> {
        try await offerRepository.getMyOffers(page: page, limit: limit)
    }
}
