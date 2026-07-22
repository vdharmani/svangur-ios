import Foundation

protocol GetDealDetailUseCaseProtocol: Sendable {
    func execute(id: Int64) async throws(AppError) -> DealListing
}

final class GetDealDetailUseCase: GetDealDetailUseCaseProtocol, Sendable {
    private let dealRepository: DealRepositoryProtocol

    init(dealRepository: DealRepositoryProtocol) {
        self.dealRepository = dealRepository
    }

    func execute(id: Int64) async throws(AppError) -> DealListing {
        guard id > 0 else {
            throw .validation(message: "Deal ID must be positive")
        }
        return try await dealRepository.getDeal(id: String(id))
    }
}
