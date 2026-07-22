import Foundation

protocol SearchOffersUseCaseProtocol: Sendable {
    func execute(query: String, lat: Double?, lng: Double?) async throws(AppError) -> [SearchOffer]
}

final class SearchOffersUseCase: SearchOffersUseCaseProtocol, Sendable {
    private let searchResultsRepository: SearchResultsRepositoryProtocol

    init(searchResultsRepository: SearchResultsRepositoryProtocol) {
        self.searchResultsRepository = searchResultsRepository
    }

    func execute(query: String, lat: Double?, lng: Double?) async throws(AppError) -> [SearchOffer] {
        try await searchResultsRepository.search(query: query, lat: lat, lng: lng)
    }
}
