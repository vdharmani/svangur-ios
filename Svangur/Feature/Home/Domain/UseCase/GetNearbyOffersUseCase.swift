import Foundation

protocol GetNearbyOffersUseCaseProtocol: Sendable {
    func execute() async throws(AppError) -> [Offer]
}

final class GetNearbyOffersUseCase: GetNearbyOffersUseCaseProtocol, Sendable {
    private let offerRepository: OfferRepositoryProtocol

    init(offerRepository: OfferRepositoryProtocol) {
        self.offerRepository = offerRepository
    }

    func execute() async throws(AppError) -> [Offer] {
        try await offerRepository.getMyOffers(page: 1, limit: 50).items
    }
}
