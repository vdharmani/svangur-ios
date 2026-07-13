protocol GetOfferAnalyticsUseCaseProtocol: Sendable {
    func execute(id: Int64) async throws(AppError) -> OfferAnalytics
}

final class GetOfferAnalyticsUseCase: GetOfferAnalyticsUseCaseProtocol, Sendable {
    private let offerRepository: OfferRepositoryProtocol

    init(offerRepository: OfferRepositoryProtocol) {
        self.offerRepository = offerRepository
    }

    func execute(id: Int64) async throws(AppError) -> OfferAnalytics {
        guard id > 0 else {
            throw .validation(message: "Offer ID must be positive")
        }
        return try await offerRepository.getAnalytics(id: id)
    }
}
